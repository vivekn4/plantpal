import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/watering.dart';

Plant _plant({DateTime? lastWatered, int intervalDays = 10}) {
  return Plant(
    id: 'p1',
    name: 'Fern',
    speciesId: 'fern',
    intervalDays: intervalDays,
    createdUtc: DateTime.utc(2026, 10, 1),
    lastWateredUtc: lastWatered,
    wateredHistoryUtc: lastWatered == null ? [] : [lastWatered],
  );
}

void main() {
  test('just watered reads 1.0, halfway reads 0.5, overdue reads 0.0', () {
    final last = DateTime.utc(2026, 10, 1);
    expect(estimatedWaterLevel(_plant(lastWatered: last), last), 1.0);
    expect(
      estimatedWaterLevel(_plant(lastWatered: last), DateTime.utc(2026, 10, 6)),
      0.5,
    );
    expect(
      estimatedWaterLevel(_plant(lastWatered: last), DateTime.utc(2026, 10, 20)),
      0.0,
    );
  });

  test('never-watered plant has no level, not a made-up number', () {
    expect(
      estimatedWaterLevel(_plant(), DateTime.utc(2026, 10, 5)),
      isNull,
    );
  });
}
