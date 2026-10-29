import 'package:flutter/material.dart';

import '../models/plant.dart';
import '../services/watering.dart';
import '../theme/app_theme.dart';

/// Text badge for a plant's watering state ("due tomorrow",
/// "2 days overdue", "happy"). Text is always present — colour is
/// never the only signal.
class DueBadge extends StatelessWidget {
  const DueBadge({super.key, required this.plant, required this.nowUtc});

  final Plant plant;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final status = statusAt(plant, nowUtc);
    final badge = dueBadge(plant, nowUtc);
    // Fade between badge texts when the state changes (watered,
    // snoozed, interval edited) instead of a hard text swap.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Text(
        badge,
        key: ValueKey(badge),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: status == WateringStatus.overdue
              ? PlantColors.danger
              : PlantColors.soil,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
