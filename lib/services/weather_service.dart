import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/weather.dart';
import 'plant_store.dart';

/// Sudbury, Ontario — the fallback when location is off or denied.
/// The UI always labels fallback weather as Sudbury, never as local
/// (PLAN.md bug 5).
const double sudburyLat = 46.49;
const double sudburyLon = -80.99;

/// Open-Meteo: free, no key, no signup. The app's only network call,
/// and it never carries a photo.
class WeatherService {
  WeatherService({http.Client? client, required this.store})
      : _client = client ?? http.Client();

  final http.Client _client;
  final PlantStore store;

  Future<WeatherSnapshot?> fetch({
    required bool useLocation,
    bool forceRefresh = false,
  }) async {
    var lat = sudburyLat;
    var lon = sudburyLon;
    var fallback = true;
    if (useLocation) {
      final position = await _devicePosition();
      if (position != null) {
        lat = position.latitude;
        lon = position.longitude;
        fallback = false;
      }
    }
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code,is_day,wind_speed_10m'
        '&forecast_days=1',
      );
      // 10s timeout: a slow network must never block the pet (bug 6).
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != 200) throw Exception('weather ${response.statusCode}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final current = body['current'] as Map<String, dynamic>;
      final snapshot = WeatherSnapshot(
        kind: weatherKindFromCode(
          (current['weather_code'] as num?)?.toInt() ?? -1,
        ),
        temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
        isDay: (current['is_day'] as num?)?.toInt() == 1,
        isFallbackLocation: fallback,
        windKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        fetchedAtUtc: DateTime.now().toUtc(),
      );
      await store.saveCachedWeather(jsonEncode(snapshot.toJson()));
      return snapshot;
    } catch (_) {
      // Offline or slow: show the last good weather, marked stale.
      // The pet renders before weather arrives either way.
      final cached = store.loadCachedWeather();
      if (cached != null) {
        try {
          final snapshot = WeatherSnapshot.fromJson(
            jsonDecode(cached) as Map<String, dynamic>,
          );
          return snapshot;
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  Future<Position?> _devicePosition() async {
    if (kIsWeb) {
      // Geolocator web support exists, but permission prompts on web
      // are noisy and unreliable; Sudbury fallback stays honest.
      return null;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }
}
