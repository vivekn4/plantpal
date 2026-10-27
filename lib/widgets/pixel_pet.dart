import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/pet_state_resolver.dart';
import '../theme/app_theme.dart';

/// The animated pet. Drawn in code: a code-drawn plant when there is
/// no photo avatar, or the user's pixelated photo with a code-drawn
/// face on top — so mood changes never require re-pixelating.
///
/// Animation is frame-based and driven by one controller. When the
/// system asks for reduced motion, idle animation drops to a gentle
/// bob (and callers may pass [reducedMotion] directly).
class PixelPet extends StatefulWidget {
  const PixelPet({
    super.key,
    required this.mood,
    this.avatarBytes,
    this.size = 220,
    this.celebrating = false,
    this.reducedMotion = false,
    this.windy = false,
  });

  final PetMood mood;
  final Uint8List? avatarBytes;
  final double size;
  final bool celebrating;
  final bool reducedMotion;

  /// Wind effects layer (wind >= 30 km/h): sway on top of the mood,
  /// even when the mood itself is rain or snow. Callers pass
  /// [windSwayApplies] so sleeping/thirsty/restless pets stay clean.
  final bool windy;

  @override
  State<PixelPet> createState() => _PixelPetState();
}

class _PixelPetState extends State<PixelPet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // Always running: the build step decides the amplitude, so
    // reduced motion still gets its gentle bob instead of freezing.
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = widget.reducedMotion ||
        MediaQuery.of(context).disableAnimations;
    final scene = widget.mood == PetMood.sleeping
        ? PlantColors.night
        : widget.mood == PetMood.thirsty
            ? const Color(0xFFE8DCC3)
            : PlantColors.cream;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: scene,
        border: Border.all(color: PlantColors.soilDark, width: 3),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Reduced motion honours MediaQuery.disableAnimations: no
          // flutter, tremble, or big bounce — just a slow, small bob
          // (1.5 px), so the pet still feels alive without moving much.
          final bounce = reduced
              ? math.sin(t * math.pi * 2) * 1.5
              : math.sin(t * math.pi * 2) *
                  (widget.mood == PetMood.energetic ? 7.0 : 4.0);
          final celebrateJump =
              widget.celebrating ? (reduced ? -4.0 : -12.0) : 0.0;
          final sway = !reduced &&
                  (widget.windy || widget.mood == PetMood.windy)
              ? math.sin(t * math.pi * 2) * 0.08
              : 0.0;
          final tremble = !reduced && widget.mood == PetMood.snowy
              ? math.sin(t * math.pi * 10) * 1.5
              : 0.0;
          final squash = widget.mood == PetMood.thirsty ? 0.92 : 1.0;
          return Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(tremble, bounce + celebrateJump),
                  child: Transform.rotate(
                    angle: sway,
                    child: Transform.scale(
                      scaleY: squash,
                      child: SizedBox(
                        width: widget.size * 0.78,
                        height: widget.size * 0.78,
                        child: Stack(
                          children: [
                            if (widget.avatarBytes != null)
                              Positioned.fill(
                                child: Image.memory(
                                  widget.avatarBytes!,
                                  filterQuality: FilterQuality.none,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else
                              const Positioned.fill(child: _CodePet()),
                            Positioned.fill(
                              child: CustomPaint(
                                // Faces and particles freeze under
                                // reduced motion; only the gentle bob
                                // above keeps moving.
                                painter: _FacePainter(
                                  widget.mood,
                                  reduced ? 0.5 : t,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(
                    widget.mood,
                    reduced ? 0.5 : t,
                    widget.celebrating,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The sample pet: pot, soil, and leaves, all drawn in code.
/// Also the empty-state pet — never a fake photo.
class _CodePet extends StatelessWidget {
  const _CodePet();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CodePetPainter());
  }
}

class _CodePetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final leafPaint = Paint()..color = PlantColors.leaf;
    final brightPaint = Paint()..color = PlantColors.leafBright;
    final potPaint = Paint()..color = PlantColors.pot;
    final soilPaint = Paint()..color = PlantColors.soil;

    // Leaves: five chunky ellipses fanning out of the pot.
    for (var i = 0; i < 5; i++) {
      final angle = -0.9 + i * 0.45;
      final paint = i.isEven ? leafPaint : brightPaint;
      canvas.save();
      canvas.translate(w * 0.5, h(size) * 0.62);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, -h(size) * 0.22),
            width: w * 0.16,
            height: h(size) * 0.48,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
    // Soil and pot.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.22, h(size) * 0.58, w * 0.56, h(size) * 0.06),
      soilPaint,
    );
    final pot = Path()
      ..moveTo(w * 0.2, h(size) * 0.64)
      ..lineTo(w * 0.8, h(size) * 0.64)
      ..lineTo(w * 0.72, h(size) * 0.95)
      ..lineTo(w * 0.28, h(size) * 0.95)
      ..close();
    canvas.drawPath(pot, potPaint);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, h(size) * 0.60, w * 0.64, h(size) * 0.06),
      potPaint,
    );
  }

  double h(Size size) => size.height;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Code-drawn face: eyes and mouth change with mood. Drawn on top of
/// the avatar, never baked into it.
class _FacePainter extends CustomPainter {
  _FacePainter(this.mood, this.t);

  final PetMood mood;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final eyeY = h * 0.42;
    final left = Offset(w * 0.36, eyeY);
    final right = Offset(w * 0.64, eyeY);
    final eyeR = w * 0.045;
    final dark = Paint()
      ..color = PlantColors.soilDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, w * 0.012)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = PlantColors.soilDark;

    // Blink: eyes shut briefly once per cycle (not when sleeping,
    // where they are always shut).
    final blinking = mood != PetMood.sleeping && t > 0.92;

    void openEye(Offset centre, {double pupilDx = 0}) {
      canvas.drawCircle(centre, eyeR, fill);
      canvas.drawCircle(
        centre + Offset(pupilDx + eyeR * 0.3, -eyeR * 0.3),
        eyeR * 0.3,
        Paint()..color = Colors.white,
      );
    }

    void shutEye(Offset centre, {bool happyArc = false}) {
      final rect = Rect.fromCircle(center: centre, radius: eyeR);
      canvas.drawArc(
        rect,
        happyArc ? math.pi * 1.15 : math.pi * 0.15,
        math.pi * 0.7,
        false,
        dark,
      );
    }

    switch (mood) {
      case PetMood.sleeping:
        shutEye(left);
        shutEye(right);
      case PetMood.basking:
        shutEye(left, happyArc: true);
        shutEye(right, happyArc: true);
      case PetMood.sleepy:
        canvas.drawLine(
          left + Offset(-eyeR, 0),
          left + Offset(eyeR, 0),
          dark,
        );
        canvas.drawLine(
          right + Offset(-eyeR, 0),
          right + Offset(eyeR, 0),
          dark,
        );
      case PetMood.restless:
        // Looks toward the water can (to the right).
        openEye(left, pupilDx: eyeR * 0.4);
        openEye(right, pupilDx: eyeR * 0.4);
      case PetMood.thirsty:
        // Droopy lids: open eye with a lid line over the top half.
        openEye(left);
        openEye(right);
        canvas.drawLine(
          left + Offset(-eyeR, -eyeR * 0.2),
          left + Offset(eyeR, -eyeR * 0.2),
          dark,
        );
        canvas.drawLine(
          right + Offset(-eyeR, -eyeR * 0.2),
          right + Offset(eyeR, -eyeR * 0.2),
          dark,
        );
      default:
        if (blinking) {
          shutEye(left);
          shutEye(right);
        } else {
          openEye(left);
          openEye(right);
        }
    }

    // Mouth.
    final mouthY = h * 0.55;
    final mouthRect = Rect.fromCircle(
      center: Offset(w * 0.5, mouthY),
      radius: w * 0.06,
    );
    switch (mood) {
      case PetMood.sleeping:
        canvas.drawCircle(
          Offset(w * 0.5, mouthY),
          w * 0.015,
          fill,
        );
      case PetMood.thirsty:
        canvas.drawArc(mouthRect, math.pi * 1.15, math.pi * 0.7, false, dark);
      case PetMood.snowy:
        canvas.drawLine(
          Offset(w * 0.44, mouthY),
          Offset(w * 0.56, mouthY),
          dark,
        );
      default:
        canvas.drawArc(mouthRect, math.pi * 0.15, math.pi * 0.7, false, dark);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.t != t;
  }
}

/// Weather and celebration particles, all drawn in code.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.mood, this.t, this.celebrating);

  final PetMood mood;
  final double t;
  final bool celebrating;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dropPaint = Paint()
      ..color = PlantColors.water
      ..strokeWidth = math.max(2, w * 0.01)
      ..strokeCap = StrokeCap.round;
    final whitePaint = Paint()..color = Colors.white;

    void sparkleAt(Offset centre, double radius, double alpha) {
      final paint = Paint()
        ..color = PlantColors.sun.withValues(alpha: alpha)
        ..strokeWidth = math.max(2, w * 0.008)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        centre + Offset(-radius, 0),
        centre + Offset(radius, 0),
        paint,
      );
      canvas.drawLine(
        centre + Offset(0, -radius),
        centre + Offset(0, radius),
        paint,
      );
    }

    if (celebrating) {
      // Droplet burst + sparkles: the best moment in the app.
      for (var i = 0; i < 10; i++) {
        final angle = i * math.pi / 5;
        final dist = w * 0.38;
        final centre = Offset(
          w * 0.5 + math.cos(angle) * dist,
          h * 0.45 + math.sin(angle) * dist * 0.8,
        );
        if (i.isEven) {
          canvas.drawCircle(centre, w * 0.02, dropPaint);
        } else {
          sparkleAt(centre, w * 0.04, 1);
        }
      }
    }

    switch (mood) {
      case PetMood.rainy:
        for (var i = 0; i < 12; i++) {
          final x = ((i * 0.173) % 1.0) * w;
          final y = ((t * 1.4 + i * 0.11) % 1.1) * h;
          canvas.drawLine(Offset(x, y), Offset(x - 3, y + 10), dropPaint);
        }
      case PetMood.snowy:
        for (var i = 0; i < 12; i++) {
          final x = ((i * 0.211 + math.sin(t * 6 + i) * 0.02) % 1.0) * w;
          final y = ((t * 0.5 + i * 0.09) % 1.1) * h;
          canvas.drawCircle(Offset(x, y), w * 0.015, whitePaint);
        }
      case PetMood.sleeping:
        for (var i = 0; i < 3; i++) {
          final rise = (t + i * 0.33) % 1.0;
          final textPainter = TextPainter(
            text: TextSpan(
              text: 'Z',
              style: pixelStyle(size: 10 + i * 4, color: Colors.white),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(w * (0.62 + i * 0.08), h * (0.3 - rise * 0.22)),
          );
        }
        for (var i = 0; i < 8; i++) {
          final twinkle = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 6 + i * 2));
          canvas.drawCircle(
            Offset(((i * 0.37) % 1.0) * w, ((i * 0.53) % 1.0) * h * 0.4),
            w * 0.008,
            Paint()..color = Colors.white.withValues(alpha: twinkle),
          );
        }
      case PetMood.happy:
      case PetMood.energetic:
        // Occasional sparkle twinkle, not constant motion.
        if (t > 0.6 && t < 0.9) {
          sparkleAt(Offset(w * 0.8, h * 0.2), w * 0.05, (t - 0.6) * 3);
          sparkleAt(Offset(w * 0.18, h * 0.3), w * 0.04, (0.9 - t) * 3);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.t != t ||
        oldDelegate.celebrating != celebrating;
  }
}
