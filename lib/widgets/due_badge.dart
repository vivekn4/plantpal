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
    return Text(
      dueBadge(plant, nowUtc),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: status == WateringStatus.overdue
            ? PlantColors.danger
            : PlantColors.soil,
      ),
      textAlign: TextAlign.center,
    );
  }
}
