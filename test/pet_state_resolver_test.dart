import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/weather.dart';
import 'package:plantpal/services/pet_state_resolver.dart';
import 'package:plantpal/services/watering.dart';

void main() {
  group('behaviour priority (PLAN.md 2)', () {
    test('night beats everything, even thirst', () {
      expect(
        resolvePet(
          isNight: true,
          wateringStatus: WateringStatus.overdue,
          weather: WeatherKind.sunny,
          batteryLevel: 100,
        ),
        PetMood.sleeping,
      );
    });
    test('thirst beats sunny weather and a full battery', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.overdue,
          weather: WeatherKind.sunny,
          batteryLevel: 100,
        ),
        PetMood.thirsty,
      );
    });
    test('due soon beats weather', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.dueSoon,
          weather: WeatherKind.rain,
          batteryLevel: 100,
        ),
        PetMood.restless,
      );
    });
    test('weather beats battery', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.rain,
          batteryLevel: 5,
        ),
        PetMood.rainy,
      );
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.snow,
          batteryLevel: 100,
        ),
        PetMood.snowy,
      );
    });
    test('low battery sleeps, high battery perks up', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.unknown,
          batteryLevel: 10,
        ),
        PetMood.sleepy,
      );
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.unknown,
          batteryLevel: 90,
        ),
        PetMood.energetic,
      );
    });
    test('unknown battery is neutral, never faked', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.unknown,
          batteryLevel: null,
        ),
        PetMood.happy,
      );
    });
  });

  group('wind layer', () {
    test('wind at 30 km/h bends a happy pet', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.sunny,
          batteryLevel: null,
          windKmh: 30,
        ),
        PetMood.windy,
      );
    });
    test('wind below 30 km/h does not bend the pet', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.sunny,
          batteryLevel: null,
          windKmh: 29,
        ),
        PetMood.basking,
      );
    });
    test('rain keeps its own effect even when windy', () {
      expect(
        resolvePet(
          isNight: false,
          wateringStatus: WateringStatus.happy,
          weather: WeatherKind.rain,
          batteryLevel: null,
          windKmh: 55,
        ),
        PetMood.rainy,
      );
    });
    test('wind layer applies over weather moods, never over '
        'sleeping/thirsty/restless', () {
      expect(windSwayApplies(PetMood.rainy, 55), isTrue);
      expect(windSwayApplies(PetMood.snowy, 30), isTrue);
      expect(windSwayApplies(PetMood.basking, 30), isTrue);
      expect(windSwayApplies(PetMood.happy, 30), isTrue);
      expect(windSwayApplies(PetMood.rainy, 29), isFalse);
      expect(windSwayApplies(PetMood.sleeping, 55), isFalse);
      expect(windSwayApplies(PetMood.thirsty, 55), isFalse);
      expect(windSwayApplies(PetMood.restless, 55), isFalse);
    });
  });
}
