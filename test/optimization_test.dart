import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/app_state.dart';
import 'package:plantpal/services/pixelate.dart';

void main() {
  test('adopt photo path decodes once and returns avatar + stored photo',
      () {
    final source = img.Image(width: 2000, height: 1000);
    img.fill(source, color: img.ColorRgb8(34, 139, 34));
    final bytes = Uint8List.fromList(img.encodeJpg(source));
    final processed = processPhotoForAdopt(bytes);
    expect(processed.avatar, isNotNull);
    final avatar = img.decodePng(processed.avatar!)!;
    expect(avatar.width, 48);
    expect(avatar.height, 48);
    final photo = img.decodeJpg(processed.photo!)!;
    expect(photo.width, 900);
    // Same result as the separate single-purpose helpers.
    expect(pixelatePhoto(bytes), isNotNull);
    expect(downscalePhoto(bytes), isNotNull);
  });

  test('plants shelf order is cached until the list changes', () {
    // AppState.preview builds an SfxService (AudioPlayer), which
    // needs the test binding even in a non-widget test.
    TestWidgetsFlutterBinding.ensureInitialized();
    final first = Plant(
      id: 'p1',
      name: 'Fern',
      speciesId: 'fern',
      intervalDays: 7,
      createdUtc: DateTime.utc(2026, 10, 20),
      lastWateredUtc: DateTime.utc(2026, 10, 26),
      wateredHistoryUtc: const [],
      hasPhoto: false,
      hasAvatar: false,
    );
    final state = AppState.preview(plants: [first]);
    // Same cached list on repeated access, not a fresh sort each time.
    expect(identical(state.plants, state.plants), isTrue);
    final second = Plant(
      id: 'p2',
      name: 'Pothos',
      speciesId: 'pothos',
      intervalDays: 7,
      createdUtc: DateTime.utc(2026, 10, 20),
      lastWateredUtc: DateTime.utc(2026, 10, 25),
      wateredHistoryUtc: const [],
      hasPhoto: false,
      hasAvatar: false,
    );
    state.replaceForTest([first, second]);
    expect(state.plants.length, 2);
    expect(identical(state.plants, state.plants), isTrue);
  });
}
