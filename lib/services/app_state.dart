import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/care_task.dart';
import '../models/plant.dart';
import '../models/weather.dart';
import 'backup.dart';
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
    // Prefs load and notification init are independent platform
    // calls; run them together instead of one after the other.
    final notificationsService = notifications ?? NotificationService();
    final prefsFuture = SharedPreferences.getInstance();
    final notificationsFuture = notificationsService.init();
    final prefs = await prefsFuture;
    final store = PlantStore(prefs);
    final state = AppState._(
      store: store,
      photos: PhotoStorage(prefs),
      sfx: SfxService(),
      notifications: notificationsService,
      weatherService: weatherService ?? WeatherService(store: store),
      batteryService: batteryService ?? BatteryService(),
      initialPlants: store.loadPlants(),
      initialSettings: store.loadSettings(),
    );
    state._sfx.enabled = state._settings.soundOn;
    await notificationsFuture;
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

  /// Cached shelf order, rebuilt only when the plant list changes.
  /// The old getter copied and re-sorted on every access — and the
  /// home and plant screens access it on every rebuild, even when
  /// only the weather or battery changed.
  List<Plant>? _sortedCache;

  void _invalidatePlants() => _sortedCache = null;

  /// Shelf order: most urgent first (overdue, then due soon, then
  /// happy), by next due date.
  List<Plant> get plants {
    return _sortedCache ??= List.unmodifiable(
      [..._plants]..sort((a, b) => nextDue(a).compareTo(nextDue(b))),
    );
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
    // Weather (network, up to a 10s timeout) and battery (platform
    // channel) are independent — waiting for one before starting
    // the other made every refresh as slow as their sum.
    final results = await Future.wait([
      _weatherService.fetch(useLocation: _settings.useLocation),
      _batteryService.level(),
    ]);
    _weather = results[0] as WeatherSnapshot?;
    _batteryLevel = results[1] as int?;
    notifyListeners();
  }

  Future<bool> addPlant(Plant plant) async {
    final next = [..._plants, plant];
    final ok = await _store.savePlants(next);
    if (!ok) return false;
    _plants = next;
    _invalidatePlants();
    await _schedule(plant);
    notifyListeners();
    return true;
  }

  Future<bool> updatePlant(Plant plant) async {
    final next = _plants.map((p) => p.id == plant.id ? plant : p).toList();
    final ok = await _store.savePlants(next);
    if (!ok) return false;
    _plants = next;
    _invalidatePlants();
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
    final plant = _plants.where((p) => p.id == id).firstOrNull;
    final next = _plants.where((p) => p.id != id).toList();
    final ok = await _store.savePlants(next);
    if (!ok) return false;
    _plants = next;
    _invalidatePlants();
    await _photos.deleteAll(id);
    await _notifications.cancel(notificationIdFor(id));
    if (plant != null) {
      for (final task in plant.careTasks) {
        await _notifications.cancel(
          notificationIdForTask(id, task.kind.name),
        );
      }
    }
    notifyListeners();
    return true;
  }

  /// Add a care task to a plant. One task per kind: adding a kind
  /// that is already there returns false and changes nothing.
  Future<bool> addCareTask(
    String plantId,
    CareTask task,
  ) async {
    final plant = _plants.where((p) => p.id == plantId).firstOrNull;
    if (plant == null) return false;
    if (plant.careTasks.any((t) => t.kind == task.kind)) return false;
    return updatePlant(
      plant.copyWith(careTasks: [...plant.careTasks, task]),
    );
  }

  /// Mark a care task done: its next due date moves to now +
  /// interval, and its reminder is rescheduled.
  Future<bool> completeCareTask(
    String plantId,
    CareTaskKind kind,
    DateTime nowUtc,
  ) async {
    final plant = _plants.where((p) => p.id == plantId).firstOrNull;
    if (plant == null) return false;
    if (!plant.careTasks.any((t) => t.kind == kind)) return false;
    final tasks = plant.careTasks
        .map((t) => t.kind == kind ? t.doneAt(nowUtc) : t)
        .toList();
    return updatePlant(plant.copyWith(careTasks: tasks));
  }

  /// Remove a care task and cancel its reminder.
  Future<bool> deleteCareTask(
    String plantId,
    CareTaskKind kind,
  ) async {
    final plant = _plants.where((p) => p.id == plantId).firstOrNull;
    if (plant == null) return false;
    final tasks =
        plant.careTasks.where((t) => t.kind != kind).toList();
    if (tasks.length == plant.careTasks.length) return false;
    final ok = await updatePlant(plant.copyWith(careTasks: tasks));
    if (ok) {
      await _notifications.cancel(
        notificationIdForTask(plantId, kind.name),
      );
    }
    return ok;
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

  /// Export the current shelf as backup text. Avatars are read
  /// here, not in the UI, so the Settings screen never touches
  /// photo storage directly.
  Future<String> exportBackup() async {
    final avatars = <String, Uint8List?>{};
    for (final plant in _plants) {
      avatars[plant.id] = await _photos.readAvatar(plant.id);
    }
    return buildBackupJson(
      plants: _plants,
      avatars: avatars,
      settings: _settings,
      exportedAtUtc: DateTime.now().toUtc(),
    );
  }

  /// Import a backup, replacing the current shelf. Returns the
  /// imported plant count, or null when the text did not validate
  /// — in which case nothing at all is changed, not even settings.
  ///
  /// Order matters for safety: validate first, save the new
  /// plants second, and only then clean up the old plants' photos
  /// and reminders. A failed plant save leaves the old shelf,
  /// photos, and reminders exactly as they were.
  Future<int?> importBackup(String text) async {
    final data = parseBackup(text);
    if (data == null) return null;
    final oldPlants = _plants;
    final ok = await _store.savePlants(data.plants);
    if (!ok) return null;
    _plants = data.plants;
    _invalidatePlants();
    // Old plants that are gone: delete their photos and reminders.
    for (final old in oldPlants) {
      if (data.plants.any((p) => p.id == old.id)) continue;
      await _photos.deleteAll(old.id);
      await _notifications.cancel(notificationIdFor(old.id));
      for (final task in old.careTasks) {
        await _notifications.cancel(
          notificationIdForTask(old.id, task.kind.name),
        );
      }
    }
    // Plants that survived the replace, but whose original photo
    // was never in the backup: drop that photo too, so hasPhoto
    // (already false in the parsed plants) matches what is on disk.
    for (final plant in data.plants) {
      final wasThere = oldPlants.any((p) => p.id == plant.id);
      if (!wasThere) continue;
      await _photos.deleteAll(plant.id);
    }
    // Avatars from the backup, saved after the cleanup above.
    for (final entry in data.avatars.entries) {
      await _photos.saveAvatar(entry.key, entry.value);
    }
    // Settings from the backup, then reminders for the new shelf.
    final settingsOk = await _store.saveSettings(data.settings);
    if (settingsOk) {
      _settings = data.settings;
      _sfx.enabled = data.settings.soundOn;
    }
    for (final plant in data.plants) {
      await _schedule(plant);
    }
    notifyListeners();
    return data.plants.length;
  }

  /// Replace the plant list (used by previews/tests that already own
  /// their plants). Not part of the normal user flow.
  void replaceForTest(List<Plant> plants) {
    _plants = plants;
    _invalidatePlants();
    notifyListeners();
  }

  Future<void> _schedule(Plant plant) async {
    await _notifications.scheduleWatering(
      id: notificationIdFor(plant.id),
      plantName: plant.name,
      dueUtc: nextDue(plant),
    );
    // Care tasks get their own reminders, on their own ids, so a
    // task reminder never overwrites the watering reminder.
    for (final task in plant.careTasks) {
      await _notifications.scheduleWatering(
        id: notificationIdForTask(plant.id, task.kind.name),
        plantName: plant.name,
        dueUtc: task.nextDueUtc,
        title: 'Time to ${task.kind.label.toLowerCase()} ${plant.name}',
        body: '${plant.name} is due for ${task.kind.label.toLowerCase()}.',
      );
    }
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
