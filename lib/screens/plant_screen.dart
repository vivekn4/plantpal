import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/app_state.dart';
import '../services/pet_state_resolver.dart';
import '../services/watering.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_pet.dart';
import '../widgets/due_badge.dart';
import '../widgets/pixel_button.dart';
import '../widgets/speech_bubble.dart';

/// One pet, big: speech bubble, next-watering date in plain words,
/// interval editor, watering history, delete.
class PlantScreen extends StatefulWidget {
  const PlantScreen({super.key, required this.state, required this.plantId});

  final AppState state;
  final String plantId;

  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> {
  bool _celebrating = false;
  int? _editedInterval;
  Uint8List? _photoBytes;
  Timer? _celebrateTimer;

  @override
  void initState() {
    super.initState();
    widget.state.photos.readPhoto(widget.plantId).then((bytes) {
      if (mounted) setState(() => _photoBytes = bytes);
    });
  }

  @override
  void dispose() {
    _celebrateTimer?.cancel();
    super.dispose();
  }

  Future<void> _water() async {
    final ok = await widget.state.waterPlant(
      widget.plantId,
      DateTime.now().toUtc(),
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That did not save. Try again.')),
      );
      return;
    }
    await widget.state.sfx.water();
    setState(() => _celebrating = true);
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _celebrating = false);
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this plant?'),
        content: const Text(
          'This deletes the plant, its photo, and its watering history '
          'from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await widget.state.deletePlant(widget.plantId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That did not save. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final plant = widget.state.plants
            .where((p) => p.id == widget.plantId)
            .firstOrNull;
        if (plant == null) {
          return const Scaffold(
            body: Center(child: Text('This plant is no longer here.')),
          );
        }
        final now = DateTime.now().toUtc();
        final status = statusAt(plant, now);
        final mood = resolvePet(
          isNight: widget.state.isNight,
          wateringStatus: status,
          weather: widget.state.weather?.kind ?? WeatherKind.unknown,
          batteryLevel: widget.state.batteryLevel,
          windKmh: widget.state.weather?.windKmh ?? 0,
        );
        final estimated = plant.lastWateredUtc == null;
        final interval = _editedInterval ?? plant.intervalDays;
        final newDue = recomputedDue(plant, interval);
        final intervalChanged = interval != plant.intervalDays;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              plant.name,
              style: pixelStyle(size: 13, color: Colors.white),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpeechBubble(
                  text: speechFor(mood, estimatedFirstDue: estimated),
                ),
                const SizedBox(height: 16),
                Center(
                  child: AvatarPet(
                    state: widget.state,
                    plantId: plant.id,
                    mood: mood,
                    size: 240,
                    celebrating: _celebrating,
                    windy: windSwayApplies(
                      mood,
                      widget.state.weather?.windKmh ?? 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DueBadge(plant: plant, nowUtc: now),
                const SizedBox(height: 4),
                Text(
                  nextWateringWords(plant),
                  textAlign: TextAlign.center,
                ),
                if (estimated) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "First reminder estimated — tap 'I watered it' to "
                    'start the real clock.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                PixelButton(
                  label: 'I watered it',
                  onPressed: _water,
                ),
                const SizedBox(height: 24),
                Text('Water every $interval days', style: pixelStyle(size: 11)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      // Fewer days between waterings = water more often.
                      tooltip: 'Water more often',
                      onPressed: interval > 1
                          ? () => setState(
                                () => _editedInterval = interval - 1,
                              )
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        '$interval days',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      // More days between waterings = water less often.
                      tooltip: 'Water less often',
                      onPressed: () => setState(
                        () => _editedInterval = interval + 1,
                      ),
                    ),
                  ],
                ),
                if (intervalChanged) ...[
                  Text(
                    // Never show a "moves from X to X" preview: when
                    // the new date equals the old one, say so plainly.
                    newDue == nextDue(plant)
                        ? 'Due date stays on ${shortDate(newDue)}.'
                        : 'Due date moves from ${shortDate(nextDue(plant))} '
                            'to ${shortDate(newDue)}.',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  PixelButton(
                    label: 'Confirm new interval',
                    color: PlantColors.leaf,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      // For a never-watered plant the preview date
                      // only sticks if the estimated first due date
                      // moves with the interval; otherwise the save
                      // would silently undo the previewed move.
                      final updated = plant.lastWateredUtc == null
                          ? plant.copyWith(
                              intervalDays: interval,
                              firstDueUtc: newDue,
                            )
                          : plant.copyWith(intervalDays: interval);
                      final ok =
                          await widget.state.updatePlant(updated);
                      if (!mounted) return;
                      if (ok) {
                        setState(() => _editedInterval = null);
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('That did not save. Try again.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Text('Watering history', style: pixelStyle(size: 11)),
                const SizedBox(height: 8),
                if (plant.wateredHistoryUtc.isEmpty)
                  const Text('Nothing yet. Water once and it shows up here.')
                else
                  ...plant.wateredHistoryUtc.reversed.map(
                    (date) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('Watered on ${shortDate(date)}'),
                    ),
                  ),
                if (_photoBytes != null) ...[
                  const SizedBox(height: 24),
                  Text('Your photo', style: pixelStyle(size: 11)),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.memory(
                      _photoBytes!,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PixelButton(
                  label: 'Remove this plant',
                  color: PlantColors.danger,
                  onPressed: _delete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
