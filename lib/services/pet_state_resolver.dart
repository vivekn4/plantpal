import '../models/weather.dart';
import 'watering.dart';

/// What the pet is doing right now. Every animation maps to a real
/// input; nothing is random decoration (PLAN.md 2).
enum PetMood {
  sleeping,
  thirsty,
  restless,
  basking,
  windy,
  rainy,
  snowy,
  sleepy,
  energetic,
  happy,
}

/// Wind speed at or above this adds the wind effects layer
/// (ARCHITECTURE.md 6.2).
const double windyThresholdKmh = 30;

/// Priority order (PLAN.md 2): night > overdue > due-soon > weather >
/// battery. A due-soon pet is a watering state too, so it also sits
/// above weather: a pet asking for water should not look like it is
/// just enjoying the sun. Wind is an effects layer, not a competing
/// mood: at 30 km/h or more it adds sway on top of the winning
/// weather mood (rain + wind still reads as rain, with flutter),
/// unless a watering or night state wins outright (see
/// [windSwayApplies]).
PetMood resolvePet({
  required bool isNight,
  required WateringStatus wateringStatus,
  required WeatherKind weather,
  required int? batteryLevel,
  double windKmh = 0,
}) {
  if (isNight) return PetMood.sleeping;
  if (wateringStatus == WateringStatus.overdue) return PetMood.thirsty;
  if (wateringStatus == WateringStatus.dueSoon) return PetMood.restless;
  switch (weather) {
    case WeatherKind.rain:
      return PetMood.rainy;
    case WeatherKind.snow:
      return PetMood.snowy;
    case WeatherKind.sunny:
      if (windKmh >= windyThresholdKmh) return PetMood.windy;
      return PetMood.basking;
    case WeatherKind.cloudy:
    case WeatherKind.unknown:
      if (windKmh >= windyThresholdKmh) return PetMood.windy;
      break;
  }
  if (batteryLevel != null) {
    if (batteryLevel < 20) return PetMood.sleepy;
    if (batteryLevel >= 70) return PetMood.energetic;
  }
  return PetMood.happy;
}

/// Whether the wind sway layer applies for a resolved mood. Wind at
/// or above [windyThresholdKmh] bends the pet whenever the winning
/// mood is a weather, battery, or happy mood — never over sleeping,
/// thirsty, or restless, where the watering/night state must read
/// cleanly on its own.
bool windSwayApplies(PetMood mood, double windKmh) {
  if (windKmh < windyThresholdKmh) return false;
  return switch (mood) {
    PetMood.sleeping || PetMood.thirsty || PetMood.restless => false,
    _ => true,
  };
}

/// Short, plain speech for the bubble. The pet talks about the plant,
/// never about itself as a program, and never guilts the user.
String speechFor(PetMood mood, {bool estimatedFirstDue = false}) {
  switch (mood) {
    case PetMood.sleeping:
      return 'Zzz…';
    case PetMood.thirsty:
      return "I'm thirsty!";
    case PetMood.restless:
      return estimatedFirstDue
          ? 'First reminder is an estimate.'
          : 'Watering time is coming up.';
    case PetMood.basking:
      return 'Ah, that sun feels good.';
    case PetMood.windy:
      return 'Wheee, what a breeze.';
    case PetMood.rainy:
      return 'A drink from the sky.';
    case PetMood.snowy:
      return 'Brr… a little chilly.';
    case PetMood.sleepy:
      return 'Getting sleepy…';
    case PetMood.energetic:
      return 'Feeling full of beans today.';
    case PetMood.happy:
      return 'All good here.';
  }
}
