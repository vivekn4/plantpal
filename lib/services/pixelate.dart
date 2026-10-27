import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The 16-bit palette. Every avatar cell snaps to one of these colours:
/// greens, earth tones, pot colours, and warm neutrals. Chunky pixels,
/// hard edges, no smoothing (PLAN.md 5).
const List<int> pixelPalette = [
  0xFF1B5E20, // deep leaf
  0xFF2E7D32, // leaf
  0xFF43A047, // bright leaf
  0xFF66BB6A, // light leaf
  0xFFA5D6A7, // pale leaf
  0xFF33691E, // dark olive
  0xFF6D4C41, // soil brown
  0xFF8D6E63, // light soil
  0xFF4E342E, // dark soil
  0xFFC1663E, // terracotta pot
  0xFFA0522D, // dark terracotta
  0xFFFFF6E3, // warm cream
  0xFF2E86DE, // water blue
];

int _nearestPalette(int r, int g, int b) {
  var best = pixelPalette.first;
  var bestDist = 1 << 30;
  for (final color in pixelPalette) {
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    final dr = r - cr;
    final dg = g - cg;
    final db = b - cb;
    final dist = dr * dr + dg * dg + db * db;
    if (dist < bestDist) {
      bestDist = dist;
      best = color;
    }
  }
  return best;
}

/// Quantize one decoded image to the palette, in place.
void quantizeToPalette(img.Image image) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final snapped = _nearestPalette(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      image.setPixelRgba(
        x,
        y,
        (snapped >> 16) & 0xFF,
        (snapped >> 8) & 0xFF,
        snapped & 0xFF,
        255,
      );
    }
  }
}

/// One cleanup pass: a cell surrounded on all four sides by the same
/// different colour is single-pixel noise — fill it in so the pet's
/// silhouette stays readable at 120px wide.
void denoise(img.Image image) {
  final width = image.width;
  final height = image.height;
  final copy = img.Image.from(image);
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final up = copy.getPixel(x, y - 1);
      final down = copy.getPixel(x, y + 1);
      final left = copy.getPixel(x - 1, y);
      final right = copy.getPixel(x + 1, y);
      if (up == down && down == left && left == right) {
        final centre = copy.getPixel(x, y);
        if (centre != up) {
          image.setPixel(x, y, up);
        }
      }
    }
  }
}

/// Photo -> 16-bit avatar. Centre-crop to square, downscale to a small
/// grid with nearest-neighbour sampling (no smoothing), quantize to the
/// fixed palette, denoise, encode as PNG bytes.
///
/// Returns null when the bytes are not a readable image — the caller
/// shows a plain hint instead of failing (PLAN.md 5).
Uint8List? pixelatePhoto(Uint8List bytes, {int grid = 48}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final side = decoded.width < decoded.height
      ? decoded.width
      : decoded.height;
  final cropped = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = img.copyResize(
    cropped,
    width: grid,
    height: grid,
    interpolation: img.Interpolation.nearest,
  );
  quantizeToPalette(small);
  denoise(small);
  return Uint8List.fromList(img.encodePng(small));
}

/// Downscale an original photo for storage (max side [maxSide] px,
/// JPEG). Keeps on-device storage small without touching the avatar.
Uint8List? downscalePhoto(Uint8List bytes, {int maxSide = 900}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  if (decoded.width <= maxSide && decoded.height <= maxSide) {
    return bytes;
  }
  final scale = maxSide / (decoded.width > decoded.height
      ? decoded.width
      : decoded.height);
  final resized = img.copyResize(
    decoded,
    width: (decoded.width * scale).round(),
    height: (decoded.height * scale).round(),
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
}
