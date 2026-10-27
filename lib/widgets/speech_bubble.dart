import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pixel speech bubble: short, plain lines only. The pet talks about
/// the plant, never in paragraphs.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PlantColors.soilDark, width: 3),
        boxShadow: const [
          BoxShadow(color: PlantColors.soilDark, offset: Offset(4, 4)),
        ],
      ),
      child: Text(text, style: pixelStyle(size: 11)),
    );
  }
}
