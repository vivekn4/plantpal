import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/notification_service.dart';
import 'package:plantpal/services/plant_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('write-then-verify round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PlantStore(prefs);
    final plant = Plant(
      id: 'p9',
      name: 'Basil',
      speciesId: 'other',
      intervalDays: 7,
      createdUtc: DateTime.utc(2026, 10, 26, 12),
    );
    expect(await store.savePlants([plant]), isTrue);
    expect(store.loadPlants().first.name, 'Basil');
    expect(store.loadSettings().soundOn, isTrue);
    expect(
      await store.saveSettings(
        store.loadSettings().copyWith(soundOn: false),
      ),
      isTrue,
    );
    expect(store.loadSettings().soundOn, isFalse);
  });

  test('corrupt plant JSON starts empty and flags, never crashes', () async {
    SharedPreferences.setMockInitialValues({'plants_v1': 'not-json['});
    final prefs = await SharedPreferences.getInstance();
    final store = PlantStore(prefs);
    expect(store.loadPlants(), isEmpty);
    expect(store.corruptDocument, isTrue);
  });

  test('reminder is 09:00 local on the due date', () {
    // Due dates are time-zone dependent by construction, so this test
    // pins the shape (hour 9, same local date) rather than an instant.
    final due = DateTime.utc(2026, 11, 2, 15);
    final now = DateTime.utc(2026, 10, 26, 12);
    final reminder = reminderTimeUtc(due, now);
    expect(reminder.toLocal().hour, 9);
    expect(reminder.toLocal().day, due.toLocal().day);
    expect(reminder.isAfter(now), isTrue);
  });

  test('reminder falls back to the due instant when 09:00 passed', () {
    final due = DateTime.utc(2026, 10, 26, 18);
    final now = DateTime.utc(2026, 10, 26, 15);
    // 09:00 local on the due date is before `now` in most zones; the
    // fallback must still be in the future, never in the past.
    final reminder = reminderTimeUtc(due, now);
    expect(reminder.isAfter(now), isTrue);
  });

  test('notification ids are stable and positive', () {
    expect(notificationIdFor('p1'), notificationIdFor('p1'));
    expect(notificationIdFor('p1'), greaterThanOrEqualTo(0));
  });
}
