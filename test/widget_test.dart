import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/main.dart';
import 'package:plantpal/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _emptyState() async {
  SharedPreferences.setMockInitialValues({});
  return AppState.create(refresh: false);
}

/// Pumps a few frames without waiting for the pet's repeating idle
/// animation to "settle" (it never does — that is the point).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('empty home shows the adopt call to action',
      (WidgetTester tester) async {
    final state = await _emptyState();
    await tester.pumpWidget(PlantPalApp(state: state));
    await _pumpFrames(tester);
    expect(find.text('Adopt your first plant'), findsOneWidget);
    expect(find.text('No plants yet. Your first pet is waiting.'),
        findsOneWidget);
  });

  testWidgets('watering an overdue plant from the shelf works',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'plants_v1':
          '[{"id":"p1","name":"Fern","speciesId":"fern","intervalDays":7,'
              '"createdUtc":"2026-10-20T12:00:00.000Z",'
              '"lastWateredUtc":"2026-10-10T12:00:00.000Z",'
              '"firstDueUtc":null,"wateredHistoryUtc":[],'
              '"hasPhoto":false,"hasAvatar":false}]',
    });
    final state = await AppState.create(refresh: false);
    await tester.pumpWidget(PlantPalApp(state: state));
    await _pumpFrames(tester);
    expect(find.text('Fern'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    await tester.ensureVisible(find.text('Water'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Water'));
    await _pumpFrames(tester);
    // After a confirmed save the pet is happy again: no Water button.
    expect(find.text('Water'), findsNothing);
    expect(state.plants.first.lastWateredUtc, isNotNull);
  });

  testWidgets('settings screen shows sound and location toggles',
      (WidgetTester tester) async {
    final state = await _emptyState();
    await tester.pumpWidget(PlantPalApp(state: state));
    await _pumpFrames(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await _pumpFrames(tester);
    expect(find.text('Sounds'), findsOneWidget);
    expect(find.text('Use my location for weather'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
  });
}
