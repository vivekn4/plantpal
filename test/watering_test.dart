import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/watering.dart';

Plant _plant({
  DateTime? lastWateredUtc,
  DateTime? firstDueUtc,
  int intervalDays = 7,
}) {
  return Plant(
    id: 'p1',
    name: 'Fern',
    speciesId: 'fern',
    intervalDays: intervalDays,
    createdUtc: DateTime.utc(2026, 10, 20, 12),
    lastWateredUtc: lastWateredUtc,
    firstDueUtc: firstDueUtc,
  );
}

void main() {
  group('moisture shift (PLAN.md 3)', () {
    final setup = DateTime.utc(2026, 10, 26, 12);
    test('dry is 2 days sooner', () {
      expect(
        firstDueFromSetup(
          setupUtc: setup,
          intervalDays: 7,
          soil: SoilFeel.dry,
        ),
        DateTime.utc(2026, 10, 31, 12),
      );
    });
    test('moist is the default interval', () {
      expect(
        firstDueFromSetup(
          setupUtc: setup,
          intervalDays: 7,
          soil: SoilFeel.moist,
        ),
        DateTime.utc(2026, 11, 2, 12),
      );
    });
    test('wet is 2 days later', () {
      expect(
        firstDueFromSetup(
          setupUtc: setup,
          intervalDays: 7,
          soil: SoilFeel.wet,
        ),
        DateTime.utc(2026, 11, 4, 12),
      );
    });
    test('dry never goes below 1 day', () {
      expect(
        firstDueFromSetup(
          setupUtc: setup,
          intervalDays: 2,
          soil: SoilFeel.dry,
        ),
        DateTime.utc(2026, 10, 27, 12),
      );
    });
  });

  group('next due + status', () {
    test('watered plant: lastWatered + interval', () {
      final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
      expect(nextDue(plant), DateTime.utc(2026, 10, 27, 12));
    });
    test('never watered: stored first due date wins', () {
      final plant = _plant(firstDueUtc: DateTime.utc(2026, 10, 28, 12));
      expect(nextDue(plant), DateTime.utc(2026, 10, 28, 12));
    });
    test('due soon within 24h, happy before that', () {
      final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
      expect(
        statusAt(plant, DateTime.utc(2026, 10, 26, 13)),
        WateringStatus.dueSoon,
      );
      expect(
        statusAt(plant, DateTime.utc(2026, 10, 26, 11)),
        WateringStatus.happy,
      );
    });
    test('overdue past the due date, counted in whole days', () {
      final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
      final now = DateTime.utc(2026, 10, 29, 18);
      expect(statusAt(plant, now), WateringStatus.overdue);
      expect(daysOverdue(plant, now), 2);
      expect(dueBadge(plant, now), '2 days overdue');
    });
    test('overdue by less than a day reads as overdue today', () {
      final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
      final now = DateTime.utc(2026, 10, 27, 18);
      expect(statusAt(plant, now), WateringStatus.overdue);
      expect(dueBadge(plant, now), 'Overdue today');
    });
  });

  group('UTC handling (PLAN.md bug 2)', () {
    test('dates survive a JSON round trip as UTC', () {
      final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
      final restored = Plant.fromJson(plant.toJson());
      expect(restored.lastWateredUtc, DateTime.utc(2026, 10, 20, 12));
      expect(restored.lastWateredUtc!.isUtc, isTrue);
      expect(nextDue(restored), nextDue(plant));
    });
    test('local-time text is normalized to UTC on load', () {
      final json = _plant().toJson()
        ..['lastWateredUtc'] =
            DateTime(2026, 10, 20, 12).toIso8601String();
      final restored = Plant.fromJson(json);
      expect(restored.lastWateredUtc!.isUtc, isTrue);
    });
  });

  group('interval edits (PLAN.md bug 9)', () {
    test('recompute from last watered with the new interval', () {
      final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
      expect(
        recomputedDue(plant, 10),
        DateTime.utc(2026, 10, 30, 12),
      );
    });
    test('never-watered plants shift their estimated first due date '
        'by the interval change, keeping the moisture shift', () {
      // Interval 7 -> 10 shifts the estimate 3 days later; 7 -> 5
      // shifts it 2 days sooner. The preview date is the saved date.
      final plant = _plant(firstDueUtc: DateTime.utc(2026, 10, 28, 12));
      expect(recomputedDue(plant, 10), DateTime.utc(2026, 10, 31, 12));
      expect(recomputedDue(plant, 5), DateTime.utc(2026, 10, 26, 12));
      expect(recomputedDue(plant, 7), DateTime.utc(2026, 10, 28, 12));
    });
  });

  test('early watering resets the clock from the new date', () {
    final plant = _plant(lastWateredUtc: DateTime.utc(2026, 10, 20, 12));
    final watered = plant.withLastWatered(
      DateTime.utc(2026, 10, 24, 9),
      [DateTime.utc(2026, 10, 24, 9)],
    );
    expect(nextDue(watered), DateTime.utc(2026, 10, 31, 9));
    expect(
      statusAt(watered, DateTime.utc(2026, 10, 24, 10)),
      WateringStatus.happy,
    );
  });
}
