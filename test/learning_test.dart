import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/learning.dart';

Plant _plant({
  required int intervalDays,
  required List<DateTime> history,
}) {
  return Plant(
    id: 'p1',
    name: 'Fern',
    speciesId: 'fern',
    intervalDays: intervalDays,
    createdUtc: DateTime.utc(2026, 10, 1),
    lastWateredUtc: history.isEmpty ? null : history.last,
    wateredHistoryUtc: history,
  );
}

void main() {
  test('median gap ignores a single late watering on holiday', () {
    // Gaps: 5, 5, 5, 20 (holiday) -> median 5, not mean 8.
    final plant = _plant(
      intervalDays: 7,
      history: [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 6),
        DateTime.utc(2026, 10, 11),
        DateTime.utc(2026, 10, 16),
        DateTime.utc(2026, 11, 5),
      ],
    );
    expect(medianGap(plant), 5);
    expect(suggestedInterval(plant), 5);
  });

  test('no suggestion with fewer than 4 waterings', () {
    final plant = _plant(
      intervalDays: 7,
      history: [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 6),
        DateTime.utc(2026, 10, 11),
      ],
    );
    expect(medianGap(plant), isNull);
    expect(suggestedInterval(plant), isNull);
    expect(learningText(plant), contains('Learning your rhythm'));
  });

  test('no suggestion when learned rhythm is within 1 day of schedule', () {
    final plant = _plant(
      intervalDays: 7,
      history: [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 7),
        DateTime.utc(2026, 10, 13),
        DateTime.utc(2026, 10, 19),
      ],
    );
    // Gaps: 6, 6, 6 -> median 6, only 1 day from 7: noise, not learning.
    expect(medianGap(plant), 6);
    expect(suggestedInterval(plant), isNull);
    expect(learningText(plant), contains('matches your schedule'));
  });

  test('same-day repeat waterings do not count as a gap', () {
    final plant = _plant(
      intervalDays: 7,
      history: [
        DateTime.utc(2026, 10, 1),
        // Same timestamp twice: a double-tap, not a rhythm.
        // (A repeat 12 hours later would make the next gap
        // 4 whole days by duration, not 5 — that is why the
        // test uses a duplicate timestamp, not a later one.)
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 6),
        DateTime.utc(2026, 10, 11),
        DateTime.utc(2026, 10, 16),
      ],
    );
    expect(wateringGaps(plant), [5, 5, 5]);
    expect(suggestedInterval(plant), 5);
  });

  test('suggestion is clamped to 1..60 days', () {
    final plant = _plant(
      intervalDays: 7,
      history: [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 5, 1),
        DateTime.utc(2026, 7, 1),
      ],
    );
    // Gaps are ~60+ days; median clamped to 60.
    expect(suggestedInterval(plant), 60);
  });
}
