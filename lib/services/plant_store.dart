import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/plant.dart';

/// App settings, stored on-device alongside the plants.
class Settings {
  const Settings({this.soundOn = true, this.useLocation = false});

  final bool soundOn;
  final bool useLocation;

  Settings copyWith({bool? soundOn, bool? useLocation}) => Settings(
        soundOn: soundOn ?? this.soundOn,
        useLocation: useLocation ?? this.useLocation,
      );

  Map<String, dynamic> toJson() =>
      {'soundOn': soundOn, 'useLocation': useLocation};

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        soundOn: json['soundOn'] as bool? ?? true,
        useLocation: json['useLocation'] as bool? ?? false,
      );
}

/// Local persistence: one JSON store for plants, one for settings
/// (shared_preferences). The builder's pick, documented in
/// ARCHITECTURE.md: a single store, no SQLite + prefs mix, and no
/// server of any kind.
class PlantStore {
  PlantStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _plantsKey = 'plants_v1';
  static const String _settingsKey = 'settings_v1';
  static const String _weatherKey = 'weather_v1';

  /// Set when the stored plant document fails to parse. The corrupt
  /// document is left untouched on disk for inspection; the app
  /// starts with an empty shelf instead of crashing.
  bool corruptDocument = false;

  List<Plant> loadPlants() {
    final raw = _prefs.getString(_plantsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Plant.fromJson(e as Map<String, dynamic>))
          .where((plant) => plant.id.isNotEmpty)
          .toList();
    } catch (_) {
      corruptDocument = true;
      return [];
    }
  }

  /// Writes plants, then re-reads and confirms the write stuck.
  /// The water tap only celebrates on a confirmed save (PLAN.md bug 7).
  Future<bool> savePlants(List<Plant> plants) async {
    final encoded = jsonEncode(plants.map((p) => p.toJson()).toList());
    final ok = await _prefs.setString(_plantsKey, encoded);
    if (!ok) return false;
    final reread = loadPlants();
    if (reread.length != plants.length) return false;
    for (var i = 0; i < plants.length; i++) {
      if (reread[i].id != plants[i].id) return false;
    }
    return true;
  }

  Settings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const Settings();
    try {
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const Settings();
    }
  }

  Future<bool> saveSettings(Settings settings) async {
    return _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  String? loadCachedWeather() => _prefs.getString(_weatherKey);

  Future<bool> saveCachedWeather(String json) async {
    return _prefs.setString(_weatherKey, json);
  }
}
