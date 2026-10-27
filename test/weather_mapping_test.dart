import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/weather.dart';

void main() {
  test('every WMO code group maps to the right pet weather', () {
    expect(weatherKindFromCode(0), WeatherKind.sunny);
    expect(weatherKindFromCode(1), WeatherKind.sunny);
    expect(weatherKindFromCode(2), WeatherKind.cloudy);
    expect(weatherKindFromCode(3), WeatherKind.cloudy);
    expect(weatherKindFromCode(45), WeatherKind.cloudy);
    expect(weatherKindFromCode(48), WeatherKind.cloudy);
    expect(weatherKindFromCode(51), WeatherKind.rain);
    expect(weatherKindFromCode(61), WeatherKind.rain);
    expect(weatherKindFromCode(67), WeatherKind.rain);
    expect(weatherKindFromCode(80), WeatherKind.rain);
    expect(weatherKindFromCode(95), WeatherKind.rain);
    expect(weatherKindFromCode(71), WeatherKind.snow);
    expect(weatherKindFromCode(77), WeatherKind.snow);
    expect(weatherKindFromCode(85), WeatherKind.snow);
    expect(weatherKindFromCode(86), WeatherKind.snow);
  });

  test('an unknown code never crashes, it maps to unknown', () {
    expect(weatherKindFromCode(999), WeatherKind.unknown);
    expect(weatherKindFromCode(-1), WeatherKind.unknown);
  });

  test('cached weather older than 60 minutes reads as stale', () {
    final old = WeatherSnapshot.fromJson({
      'kind': 'sunny',
      'temperatureC': 20,
      'isDay': true,
      'isFallbackLocation': true,
      'windKmh': 5,
      'fetchedAtUtc': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 61))
          .toIso8601String(),
    });
    expect(old.stale, isTrue);
    final fresh = WeatherSnapshot.fromJson({
      'kind': 'sunny',
      'temperatureC': 20,
      'isDay': true,
      'isFallbackLocation': true,
      'windKmh': 5,
      'fetchedAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    expect(fresh.stale, isFalse);
  });
}
