import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/screens/plant_screen.dart';
import 'package:plantpal/services/app_state.dart';
import 'package:plantpal/services/watering.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interval edit: old -> new date shown before confirm, cancel writes
/// nothing, confirm recomputes immediately (ARCHITECTURE.md 10).
void main() {
  Future<AppState> stateWithPlant() async {
    SharedPreferences.setMockInitialValues({
      'plants_v1':
          '[{"id":"p1","name":"Fern","speciesId":"fern","intervalDays":7,'
              '"createdUtc":"2026-10-20T12:00:00.000Z",'
              '"lastWateredUtc":"2026-10-20T12:00:00.000Z",'
              '"firstDueUtc":null,"wateredHistoryUtc":[],'
              '"hasPhoto":false,"hasAvatar":false}]',
    });
    return AppState.create(refresh: false);
  }

  testWidgets('interval edit previews old and new dates, then confirms',
      (WidgetTester tester) async {
    final state = await stateWithPlant();
    final before = state.plants.first;
    await tester.pumpWidget(
      MaterialApp(
        home: PlantScreen(state: state, plantId: 'p1'),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Water every 7 days'), findsOneWidget);
    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Water every 8 days'), findsOneWidget);
    // Old -> new preview is visible before confirming.
    expect(
      find.text(
        'Due date moves from ${shortDate(nextDue(before))} '
        'to ${shortDate(recomputedDue(before, 8))}.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm new interval'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(state.plants.first.intervalDays, 8);
    expect(find.text('Water every 8 days'), findsOneWidget);
  });

  testWidgets('never-watered interval edit previews a real move and '
      'saves it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'plants_v1':
          '[{"id":"p1","name":"Fern","speciesId":"fern","intervalDays":7,'
              '"createdUtc":"2026-10-20T12:00:00.000Z",'
              '"lastWateredUtc":null,'
              '"firstDueUtc":"2026-10-27T12:00:00.000Z",'
              '"wateredHistoryUtc":[],'
              '"hasPhoto":false,"hasAvatar":false}]',
    });
    final state = await AppState.create(refresh: false);
    final before = state.plants.first;
    await tester.pumpWidget(
      MaterialApp(
        home: PlantScreen(state: state, plantId: 'p1'),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.ensureVisible(find.byIcon(Icons.add_circle_outline));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump(const Duration(milliseconds: 200));
    // Old -> new must differ: a "moves from X to X" preview is a bug.
    expect(
      find.text(
        'Due date moves from ${shortDate(nextDue(before))} '
        'to ${shortDate(recomputedDue(before, 8))}.',
      ),
      findsOneWidget,
    );
    expect(nextDue(before) != recomputedDue(before, 8), isTrue);
    await tester.tap(find.text('Confirm new interval'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(state.plants.first.intervalDays, 8);
    // The saved plant's due date is the previewed date, not the old one.
    expect(nextDue(state.plants.first), recomputedDue(before, 8));
  });
}
