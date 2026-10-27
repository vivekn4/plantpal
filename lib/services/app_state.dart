import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plant.dart';
import '../models/weather.dart';
import 'battery_service.dart';
import 'notification_service.dart';
import 'photo_store.dart';
import 'plant_store.dart';
import 'sfx_service.dart';
import 'watering.dart';
import 'weather_service.dart';

/// The app's single state holder: plants, settings, weather, battery.
/// Widgets listen to this; nothing else holds plant state.
class AppState extends ChangeNotifier {
  AppState._({
    required this._store,
    required this._photos,
    required this._sfx,
    required this._notifications,
    required this._weatherService,
    required this._batteryService,
    List<Plant>? initialPlants,
    Settings? initialSettings,
  })  : _plants = initialPlants ?? [],
        _settings = initialSettings ?? const Settings();

  /// Normal startup: loads stored plants and settings, then refreshes
  /// weather and battery in the background (the pet renders first).
  /// Services can be injected for tests so widget tests never touch
  /// the network or platform channels.
  static Future<AppState> create({
    WeatherService? weatherService,
    BatteryService? batteryService,
    NotificationService? notifications,
    bool refresh = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final store = PlantStore(prefs);
    final state = AppState._(
      store: store,
      photos: PhotoStorage(prefs),
      sfx: SfxService(),
      notifications: notifications ?? NotificationService(),
      weatherService: weatherService ?? WeatherService(store: store),
      batteryService: batteryService ?? BatteryService(),
      initialPlants: store.loadPlants(),
      initialSettings: store.loadSettings(),
    );
    state._sfx.enabled = state._settings.soundOn;
    await state._notifications.init();
    if (refresh) unawaited(state.refreshEnvironment());
    return state;
  }

  final PlantStore _store;
  final PhotoStorage _photos;
  final SfxService _sfx;
  final NotificationService _notifications;
  final WeatherService _weatherService;
  final BatteryService _batteryService;

  List<Plant> _plants;
  Settings _settings;
  WeatherSnapshot? _weather;
  int? _batteryLevel;

  /// Shelf order: most urgent first (overdue, then due soon, then
  /// happy), by next due date.
  List<Plant> get plants {
    final sorted = [..._plants]
      ..sort((a, b) => nextDue(a).compareTo(nextDue(b)));
    return List.unmodifiable(sorted);
  }

  /// True when the stored plant document failed to parse at load.
  /// The app starts with an empty shelf rather than crashing, and
  /// the home screen says so plainly.
  bool get storeCorrupt => _store.corruptDocument;
  Settings get settings => _settings;
  WeatherSnapshot? get weather => _weather;
  int? get batteryLevel => _batteryLevel;
  SfxService get sfx => _sfx;
  PhotoStorage get photos => _photos;

  /// Night comes from the weather API's day flag when available,
  /// otherwise from the local hour. Weather never decides watering.
  bool get isNight {
    if (_weather != null) return !_weather!.isDay;
    final hour = DateTime.now().hour;
    return hour < 6 || hour >= 21;
  }

  String get weatherLabel {
    final snapshot = _weather;
    if (snapshot == null) return 'Weather unavailable';
    final stale = snapshot.stale ? ' (stale)' : '';
    return '${snapshot.label}, ${snapshot.temperatureC.round()}°C$stale';
  }

  String get weatherLocationNote {
    final snapshot = _weather;
    if (snapshot == null) {
      return 'Showing Sudbury weather when available — '
          'turn on location for yours.';
    }
    if (snapshot.isFallbackLocation) {
      return 'Showing Sudbury weather — turn on location for yours.';
    }
    return 'Showing weather for your location.';
  }

  Future<void> refreshEnvironment() async {
    final weather = await _weatherService.fetch(
      useLocation: _settings.useLocation,
    );
    final battery = await _batteryService.level();
    _weather = weather;
    _batteryLevel = battery;
    notifyListeners();
  }

  Future<bool> addPlant(Plant plant) async {
    final next = [..._plants, plant];
    final ok = await _store.savePlants(next);
    if (!ok) return false;
    _plants = next;
    await _schedule(plant);
    notifyListeners();
    return true;
  }

  Future<bool> updatePlant(Plant plant) async {
    final next = _plants.map((p) => p.id == plant.id ? plant : p).toList();
    final ok = await _store.savePlants(next);
    if (!ok) return false;
    _plants = next;
    await _schedule(plant);
    notifyListeners();
    return true;
  }

  /// Water a plant: persist first, celebrate only on confirmed save.
  Future<bool> waterPlant(String id, DateTime nowUtc) async {
    final plant = _plants.where((p) => p.id == id).firstOrNull;
    if (plant == null) return false;
    final updated = plant.withLastWatered(
      nowUtc,
      [...plant.wateredHistoryUtc, nowUtc],
    );
    final ok = await updatePlant(updated);
    return ok;
  }

  Future<bool> deletePlant(String id) async {
    final next = _plants.where((p) => p.id != id).toList();
    final ok = await _store.savePlants(next);
    if (!ok) return false;
    _plants = next;
    await _photos.deleteAll(id);
    await _notifications.cancel(notificationIdFor(id));
    notifyListeners();
    return true;
  }

  Future<bool> updateSettings(Settings settings) async {
    final ok = await _store.saveSettings(settings);
    if (!ok) return false;
    _settings = settings;
    _sfx.enabled = settings.soundOn;
    notifyListeners();
    unawaited(refreshEnvironment());
    return true;
  }

  /// Replace the plant list (used by previews/tests that already own
  /// their plants). Not part of the normal user flow.
  void replaceForTest(List<Plant> plants) {
    _plants = plants;
    notifyListeners();
  }

  Future<void> _schedule(Plant plant) async {
    await _notifications.scheduleWatering(
      id: notificationIdFor(plant.id),
      plantName: plant.name,
      dueUtc: nextDue(plant),
    );
  }

  /// For golden previews: a state that skips platform init entirely.
  static AppState preview({
    required List<Plant> plants,
    WeatherSnapshot? weather,
    int? batteryLevel,
  }) {
    final state = AppState._(
      store: _PreviewStore(),
      photos: _PreviewPhotos(),
      sfx: SfxService(),
      notifications: NotificationService(),
      weatherService: WeatherService(store: _PreviewStore()),
      batteryService: BatteryService(),
      initialPlants: plants,
    );
    state._weather = weather;
    state._batteryLevel = batteryLevel;
    return state;
  }
}

/// Minimal stand-ins so [AppState.preview] never touches platform
/// channels. They are never used on the save path.
class _PreviewStore extends PlantStore {
  _PreviewStore() : super(_PreviewPrefs());

  @override
  List<Plant> loadPlants() => [];

  @override
  Future<bool> savePlants(List<Plant> plants) async => true;
}

class _PreviewPrefs implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(
        invocation,
      );
}

class _PreviewPhotos extends PhotoStorage {
  _PreviewPhotos() : super(_PreviewPrefs());

  @override
  Future<void> savePhoto(String plantId, Uint8List bytes) async {}

  @override
  Future<void> saveAvatar(String plantId, Uint8List bytes) async {}

  @override
  Future<Uint8List?> readPhoto(String plantId) async => null;

  @override
  Future<Uint8List?> readAvatar(String plantId) async => null;

  @override
  Future<void> deleteAll(String plantId) async {}
}
