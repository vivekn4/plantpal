import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/services/pet_state_resolver.dart';
import 'package:plantpal/widgets/pixel_pet.dart';

/// Reduced motion honours MediaQuery.disableAnimations: the pet still
/// builds and renders under a system reduced-motion setting, with its
/// idle motion cut to a gentle bob (checked in PixelPet's build).
void main() {
  testWidgets('pet renders under MediaQuery.disableAnimations',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: PixelPet(mood: PetMood.happy, size: 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PixelPet), findsOneWidget);
    // No crash, no missing-asset error, and the widget stays up over
    // several animation frames.
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.byType(PixelPet), findsOneWidget);
  });

  testWidgets('pet renders with reducedMotion passed directly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PixelPet(
            mood: PetMood.rainy,
            size: 200,
            reducedMotion: true,
            windy: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PixelPet), findsOneWidget);
  });
}
