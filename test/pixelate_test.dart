import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plantpal/services/pixelate.dart';

void main() {
  test('pixelate returns a 48x48 PNG using only palette colours', () {
    final source = img.Image(width: 200, height: 100);
    img.fill(source, color: img.ColorRgb8(34, 139, 34));
    final bytes = Uint8List.fromList(img.encodeJpg(source));
    final avatar = pixelatePhoto(bytes);
    expect(avatar, isNotNull);
    final decoded = img.decodePng(avatar!)!;
    expect(decoded.width, 48);
    expect(decoded.height, 48);
    final palette = pixelPalette.toSet();
    for (var y = 0; y < 48; y += 7) {
      for (var x = 0; x < 48; x += 7) {
        final pixel = decoded.getPixel(x, y);
        final argb = 0xFF000000 |
            (pixel.r.toInt() << 16) |
            (pixel.g.toInt() << 8) |
            pixel.b.toInt();
        expect(palette.contains(argb), isTrue);
      }
    }
  });

  test('pixelate centre-crops wide and tall photos to square', () {
    final wide = img.Image(width: 300, height: 100);
    img.fill(wide, color: img.ColorRgb8(200, 100, 50));
    final avatar = pixelatePhoto(Uint8List.fromList(img.encodeJpg(wide)));
    final decoded = img.decodePng(avatar!)!;
    expect(decoded.width, decoded.height);
  });

  test('pixelate returns null for unreadable bytes', () {
    expect(pixelatePhoto(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('downscale caps the long side and keeps small photos as-is', () {
    final big = img.Image(width: 2000, height: 1000);
    final small = img.Image(width: 100, height: 100);
    final bigOut = downscalePhoto(Uint8List.fromList(img.encodeJpg(big)))!;
    final bigDecoded = img.decodeJpg(bigOut)!;
    expect(bigDecoded.width, 900);
    final smallBytes = Uint8List.fromList(img.encodeJpg(small));
    expect(downscalePhoto(smallBytes), smallBytes);
  });
}
