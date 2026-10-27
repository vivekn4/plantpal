import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// Small weather badge + the honest location note. Fallback weather
/// is always labelled as Sudbury, never presented as local.
class WeatherBadge extends StatelessWidget {
  const WeatherBadge({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: PlantColors.soilDark, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, size: 18, color: PlantColors.soil),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.weatherLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            state.weatherLocationNote,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
