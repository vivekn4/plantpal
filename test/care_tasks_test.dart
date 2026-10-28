import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/care_task.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/care_tasks.dart';
import 'package:plantpal/services/watering.dart';

Plant _plant({List<DateTime>? history, DateTime? lastWatered}) {
  return Plant(
    id: 'p1',
    name: 'Fern',
    speciesId: 'fern',
    intervalDays: 7,
    createdUtc: DateTime.utc(2026, 10, 1),
    lastWateredUtc: lastWatered,
    firstDueUtc: DateTime.utc(2026, 10, 8),
    wateredHistoryUtc: history ?? const [],
    hasPhoto: false,
    hasAvatar: false,
  );
}

void main() {
  test('care task due words cover happy, due soon, overdue', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    // Oct 30 minus Oct 20 12:00 is 9 whole days, matching the
    // watering badge's inDays logic.
    expect(
      careTaskDueWords(
        CareTask(
          kind: CareTaskKind.fertilize,
          intervalDays: 30,
          nextDueUtc: DateTime.utc(2026, 10, 30),
        ),
        now,
      ),
      'Fertilize in 9 days',
    );
    expect(
      careTaskDueWords(
        CareTask(
          kind: CareTaskKind.mist,
          intervalDays: 7,
          nextDueUtc: DateTime.utc(2026, 10, 21, 12),
        ),
        now,
      ),
      'Mist due tomorrow',
    );
    expect(
      careTaskDueWords(
        CareTask(
          kind: CareTaskKind.rotate,
          intervalDays: 14,
          nextDueUtc: DateTime.utc(2026, 10, 18),
        ),
        now,
      ),
      'Rotate 2 days overdue',
    );
  });

  test('completing a care task moves its due date by its interval', () {
    final task = CareTask(
      kind: CareTaskKind.fertilize,
      intervalDays: 30,
      nextDueUtc: DateTime.utc(2026, 10, 20),
    );
    final done = task.doneAt(DateTime.utc(2026, 10, 20, 12));
    expect(done.nextDueUtc, DateTime.utc(2026, 11, 19, 12));
  });

  test('care tasks sort most urgent first', () {
    final tasks = sortedCareTasks([
      CareTask(
        kind: CareTaskKind.repot,
        intervalDays: 365,
        nextDueUtc: DateTime.utc(2027, 1, 1),
      ),
      CareTask(
        kind: CareTaskKind.mist,
        intervalDays: 7,
        nextDueUtc: DateTime.utc(2026, 10, 21),
      ),
    ]);
    expect(tasks.first.kind, CareTaskKind.mist);
  });

  test('old plant JSON without tasks or note loads as empty', () {
    final plant = Plant.fromJson({
      'id': 'p1',
      'name': 'Fern',
      'speciesId': 'fern',
      'intervalDays': 7,
      'createdUtc': '2026-10-01T00:00:00.000Z',
      'lastWateredUtc': null,
      'firstDueUtc': null,
      'wateredHistoryUtc': [],
      'hasPhoto': false,
      'hasAvatar': false,
    });
    expect(plant.careTasks, isEmpty);
    expect(plant.note, '');
  });

  test('plant JSON round-trips tasks and note', () {
    final plant = _plant().copyWith(
      note: 'Likes the east window.',
      careTasks: [
        CareTask(
          kind: CareTaskKind.fertilize,
          intervalDays: 30,
          nextDueUtc: DateTime.utc(2026, 11, 1),
        ),
      ],
    );
    final restored = Plant.fromJson(plant.toJson());
    expect(restored.note, 'Likes the east window.');
    expect(restored.careTasks.length, 1);
    expect(restored.careTasks.first.kind, CareTaskKind.fertilize);
    expect(
      restored.careTasks.first.nextDueUtc,
      DateTime.utc(2026, 11, 1),
    );
  });

  test('watering a plant keeps its tasks and note', () {
    final plant = _plant(
      history: [DateTime.utc(2026, 10, 10)],
      lastWatered: DateTime.utc(2026, 10, 10),
    ).copyWith(
      note: 'Repotted in May.',
      careTasks: [
        CareTask(
          kind: CareTaskKind.mist,
          intervalDays: 7,
          nextDueUtc: DateTime.utc(2026, 10, 25),
        ),
      ],
    );
    final watered = plant.withLastWatered(
      DateTime.utc(2026, 10, 20),
      [...plant.wateredHistoryUtc, DateTime.utc(2026, 10, 20)],
    );
    expect(watered.note, 'Repotted in May.');
    expect(watered.careTasks.length, 1);
  });

  test('streak counts on-time waterings and resets on overdue', () {
    final onTime = _plant(
      history: [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 8),
        DateTime.utc(2026, 10, 15),
      ],
      lastWatered: DateTime.utc(2026, 10, 15),
    );
    // Due Oct 22, now Oct 20: happy, all three on time.
    expect(wateringStreak(onTime, DateTime.utc(2026, 10, 20)), 3);

    final overdue = _plant(
      history: [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 8),
      ],
      lastWatered: DateTime.utc(2026, 10, 8),
    );
    // Due Oct 15, now Oct 20: overdue, streak is 0.
    expect(wateringStreak(overdue, DateTime.utc(2026, 10, 20)), 0);

    final late = _plant(
      history: [
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 12),
      ],
      lastWatered: DateTime.utc(2026, 10, 12),
    );
    // Second watering was late (due Oct 8), now Oct 14, due
    // Oct 19: happy, but the late watering broke the streak.
    expect(wateringStreak(late, DateTime.utc(2026, 10, 14)), 0);
  });
}
