import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/watering.dart';

Plant _plant({
  required DateTime lastWatered,
  int intervalDays = 7,
  DateTime? snoozedUntil,
}) {
  return Plant(
    id: 'p1',
    name: 'Fern',
    speciesId: 'fern',
    intervalDays: intervalDays,
    createdUtc: DateTime.utc(2026, 10, 1),
    lastWateredUtc: lastWatered,
    wateredHistoryUtc: [lastWatered],
    snoozedUntilUtc: snoozedUntil,
  );
}

void main() {
  test('snooze pushes an overdue plant to the snoozed date', () {
    // Last watered Oct 1, interval 7 -> normally due Oct 8.
    // Snoozed to Oct 10 -> due Oct 10, not Oct 8.
    final plant = _plant(
      lastWatered: DateTime.utc(2026, 10, 1),
      snoozedUntil: DateTime.utc(2026, 10, 10),
    );
    expect(nextDue(plant), DateTime.utc(2026, 10, 10));
    expect(isSnoozed(plant, DateTime.utc(2026, 10, 9)), isTrue);
    // Due tomorrow is dueSoon, not happy — happy means more
    // than 24 hours away. The snooze still worked: without it
    // this plant would be overdue on Oct 9, not due tomorrow.
    expect(statusAt(plant, DateTime.utc(2026, 10, 9)), WateringStatus.dueSoon);
    expect(dueBadge(plant, DateTime.utc(2026, 10, 9)), 'Due tomorrow');
  });

  test('snooze never pulls a future due date earlier', () {
    // Normally due Oct 8, snoozed to Oct 5 (earlier) -> still Oct 8.
    final plant = _plant(
      lastWatered: DateTime.utc(2026, 10, 1),
      snoozedUntil: DateTime.utc(2026, 10, 5),
    );
    expect(nextDue(plant), DateTime.utc(2026, 10, 8));
    expect(isSnoozed(plant, DateTime.utc(2026, 10, 4)), isFalse);
  });

  test('snooze expires: after the snoozed date the normal clock returns', () {
    final plant = _plant(
      lastWatered: DateTime.utc(2026, 10, 1),
      snoozedUntil: DateTime.utc(2026, 10, 10),
    );
    // On Oct 11 the snooze is over, so the plant is overdue
    // against its normal Oct 8 due date, not "due" again.
    expect(isSnoozed(plant, DateTime.utc(2026, 10, 11)), isFalse);
    expect(statusAt(plant, DateTime.utc(2026, 10, 11)), WateringStatus.overdue);
  });

  test('old plant JSON without snooze loads as null', () {
    final plant = Plant.fromJson({
      'id': 'p9',
      'name': 'Old',
      'speciesId': 'fern',
      'intervalDays': 7,
      'createdUtc': DateTime.utc(2026, 10, 1).toIso8601String(),
      'lastWateredUtc': DateTime.utc(2026, 10, 1).toIso8601String(),
    });
    expect(plant.snoozedUntilUtc, isNull);
    expect(plant.withoutSnooze().snoozedUntilUtc, isNull);
  });

  test('watering clears a snooze', () {
    final plant = _plant(
      lastWatered: DateTime.utc(2026, 10, 1),
      snoozedUntil: DateTime.utc(2026, 10, 10),
    );
    final watered = plant.withLastWatered(
      DateTime.utc(2026, 10, 9),
      [...plant.wateredHistoryUtc, DateTime.utc(2026, 10, 9)],
    );
    expect(watered.snoozedUntilUtc, isNull);
    expect(nextDue(watered), DateTime.utc(2026, 10, 16));
  });
}
