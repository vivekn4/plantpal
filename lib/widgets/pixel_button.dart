import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chunky pixel button: hard border, hard shadow, and a visible
/// press-down shift. Every tappable thing must visibly react.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = PlantColors.water,
    this.textColor = Colors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final offset = _pressed ? 2.0 : 0.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.translate(
        offset: Offset(offset, offset),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? widget.color : Colors.grey,
            border: Border.all(color: PlantColors.soilDark, width: 3),
            boxShadow: _pressed
                ? const []
                : const [
                    BoxShadow(
                      color: PlantColors.soilDark,
                      offset: Offset(4, 4),
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            style: pixelStyle(size: 12, color: widget.textColor),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
