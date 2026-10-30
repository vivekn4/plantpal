import 'dart:async';

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

/// Interactive plant view — the AR-style view, built honestly.
///
/// What this IS: a full-screen interactive scene. Drag to turn
/// the plant, pinch to zoom, tap it to pet it. It shows the
/// plant's estimated water level, its assumed mood (the same
/// mood logic the shelf already uses), its watering information,
/// and the live weather information — all in one place, so the
/// plant feels like it is in front of you.
///
/// What this is NOT (yet): camera AR. True camera AR — a plant
/// anchored in your actual room through your phone camera — needs
/// ARCore/ARKit, a real phone to test on, and a plugin that
/// survives the current Flutter/Gradle setup. This box cannot
/// test any of that, and shipping an untested AR plugin as "AR"
/// would be faking it. So this screen is labelled "Interactive
/// view" in the app, and the camera step is a separate, device-
/// tested job, not a silent claim here.
///
/// The scene background follows the weather: sunny = warm light,
/// rain = cool blue, snow = pale, night = dark — the same
/// weather the pet already reacts to, now as a whole room.
class ArViewScreen extends StatefulWidget {
  const ArViewScreen({super.key, required this.state, required this.plantId});

  final AppState state;
  final String plantId;

  @override
  State<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends State<ArViewScreen> {
  double _rotationY = 0;
  double _tilt = 0;
  double _scale = 1;
  double _baseScale = 1;
  bool _celebrating = false;
  Timer? _celebrateTimer;

  @override
  void dispose() {
    _celebrateTimer?.cancel();
    super.dispose();
  }

  void _pet() {
    setState(() => _celebrating = true);
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(
      const Duration(milliseconds: 1200),
      () {
        if (mounted) setState(() => _celebrating = false);
      },
    );
  }

  Color _sceneColor(WeatherSnapshot? weather, bool isNight) {
    if (isNight) return PlantColors.night;
    return switch (weather?.kind) {
      WeatherKind.sunny => const Color(0xFFFFF3C4),
      WeatherKind.rain => const Color(0xFFD6EAF8),
      WeatherKind.snow => const Color(0xFFEAF2F8),
      WeatherKind.cloudy => const Color(0xFFEAEDED),
      _ => PlantColors.cream,
    };
  }

  String _moodWord(PetMood mood) {
    return switch (mood) {
      PetMood.sleeping => 'Sleeping',
      PetMood.thirsty => 'Thirsty!',
      PetMood.restless => 'Thirsty soon',
      PetMood.basking => 'Basking',
      PetMood.windy => 'Windy',
      PetMood.rainy => 'Rainy',
      PetMood.snowy => 'Snowy',
      PetMood.sleepy => 'Sleepy',
      PetMood.energetic => 'Energetic',
      PetMood.happy => 'Happy',
    };
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
          return Scaffold(
            appBar: AppBar(title: const Text('Interactive view')),
            body: const Center(child: Text('That plant is gone.')),
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
        final level = estimatedWaterLevel(plant, now);
        final weather = widget.state.weather;
        final scene = _sceneColor(weather, widget.state.isNight);
        final isDark = widget.state.isNight;
        final textColor = isDark ? Colors.white : PlantColors.soil;
        return Scaffold(
          backgroundColor: scene,
          appBar: AppBar(
            title: Text(
              '${plant.name} — interactive view',
              style: pixelStyle(size: 11, color: Colors.white),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Drag to turn your plant, pinch to zoom, '
                  'tap it to pet it. This is an interactive '
                  'preview — camera AR is a separate, '
                  'phone-tested step, not faked here.',
                  style: TextStyle(fontSize: 12, color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SpeechBubble(text: speechFor(mood)),
                const SizedBox(height: 8),
                // Interactive scene: rotate (drag), tilt, zoom.
                GestureDetector(
                  onScaleStart: (_) => _baseScale = _scale,
                  onScaleUpdate: (details) {
                    setState(() {
                      _scale = (_baseScale * details.scale).clamp(0.7, 2.0);
                      _rotationY += details.focalPointDelta.dx * 0.01;
                      _tilt = (_tilt + details.focalPointDelta.dy * 0.005)
                          .clamp(-0.4, 0.4);
                    });
                  },
                  onTap: () async {
                    _pet();
                    await widget.state.sfx.click();
                  },
                  child: Container(
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: PlantColors.soilDark,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: _scale,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(_rotationY)
                            ..rotateX(_tilt),
                          child: AvatarPet(
                          state: widget.state,
                          plantId: plant.id,
                          mood: mood,
                          size: 240,
                          celebrating: _celebrating,
                          windy: windSwayApplies(
                            mood,
                            weather?.windKmh ?? 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 16),
                // Water level + mood, side by side.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Water level',
                            style: pixelStyle(size: 10, color: textColor),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 120,
                            width: 48,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: PlantColors.soilDark,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                height: level == null ? 0 : 120 * level,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: level == null
                                      ? Colors.grey
                                      : Color.lerp(
                                          PlantColors.danger,
                                          PlantColors.water,
                                          level,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            level == null
                                ? 'Unknown — water once to start the gauge.'
                                : '${(level * 100).round()}% full',
                            style:
                                TextStyle(fontSize: 12, color: textColor),
                          ),
                          Text(
                            'Estimated from your watering schedule, '
                            'not a soil sensor.',
                            style:
                                TextStyle(fontSize: 11, color: textColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood',
                            style: pixelStyle(size: 10, color: textColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _moodWord(mood),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DueBadge(plant: plant, nowUtc: now),
                          const SizedBox(height: 8),
                          if (widget.state.batteryLevel != null)
                            Text(
                              'Your phone battery: '
                              '${widget.state.batteryLevel}% — '
                              'the pet gets sleepy when it is low.',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Watering information.
                Text(
                  'Watering',
                  style: pixelStyle(size: 11, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last watered: ${plant.lastWateredUtc == null ? 'not yet' : shortDate(plant.lastWateredUtc!)}',
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
                Text(
                  'Next due: ${shortDate(nextDue(plant))} '
                  '(every ${plant.intervalDays} days)',
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
                Text(
                  'Streak: ${wateringStreak(plant, now)} waterings '
                  'on time in a row',
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
                if (isSnoozed(plant, now))
                  Text(
                    'Snoozed until ${shortDate(plant.snoozedUntilUtc!)}.',
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                const SizedBox(height: 16),
                // Weather information.
                Text(
                  'Weather',
                  style: pixelStyle(size: 11, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(
                  weather == null
                      ? 'Weather unavailable.'
                      : '${weather.label}, '
                          '${weather.temperatureC.round()}°C, '
                          'wind ${weather.windKmh.round()} km/h. '
                          '${widget.state.weatherLocationNote}',
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        label: 'Water it here',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await widget.state.waterPlant(
                            plant.id,
                            DateTime.now().toUtc(),
                          );
                          if (mounted && ok) {
                            await widget.state.sfx.water();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Thanks! That hit the spot.'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PixelButton(
                        label: 'Back to plant',
                        color: PlantColors.leaf,
                        onPressed: () {
                          // AR view was pushed from the plant
                          // screen, so pop returns there — no
                          // need to push a second copy.
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
