import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../services/app_state.dart';
import '../services/pet_state_resolver.dart';
import '../services/watering.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_pet.dart';
import '../widgets/due_badge.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_pet.dart';
import '../widgets/weather_badge.dart';
import 'adopt_screen.dart';
import 'plant_screen.dart';
import 'settings_screen.dart';

/// The pet shelf: a grid of pets, each with a name, a due badge in
/// plain words, and a one-tap water button on pets that need it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  PetMood _moodFor(String plantId, WateringStatus status) {
    return resolvePet(
      isNight: state.isNight,
      wateringStatus: status,
      weather: state.weather?.kind ?? WeatherKind.unknown,
      batteryLevel: state.batteryLevel,
      windKmh: state.weather?.windKmh ?? 0,
    );
  }

  Future<void> _water(BuildContext context, String plantId) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await state.waterPlant(
      plantId,
      DateTime.now().toUtc(),
    );
    if (ok) {
      await state.sfx.water();
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks! That hit the spot.')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That did not save. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final plants = state.plants;
        final now = DateTime.now().toUtc();
        return Scaffold(
          appBar: AppBar(
            title: Text('PlantPal', style: pixelStyle(size: 16, color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await state.sfx.click();
                  await navigator.push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(state: state),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WeatherBadge(state: state),
                if (state.storeCorrupt) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: PlantColors.danger,
                        width: 2,
                      ),
                    ),
                    child: const Text(
                      "Your saved plants couldn't be read — starting "
                      'fresh. Your old save is left untouched.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (plants.isEmpty) ...[
                  const Center(
                    child: PixelPet(mood: PetMood.happy, size: 200),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No plants yet. Your first pet is waiting.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  PixelButton(
                    label: 'Adopt your first plant',
                    onPressed: () => _openAdopt(context),
                  ),
                ] else ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: plants.length,
                    itemBuilder: (context, index) {
                      final plant = plants[index];
                      final status = statusAt(plant, now);
                      final mood = _moodFor(plant.id, status);
                      final needsWater = status != WateringStatus.happy;
                      return GestureDetector(
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await state.sfx.click();
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => PlantScreen(
                                state: state,
                                plantId: plant.id,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            border: Border.all(
                              color: PlantColors.soilDark,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              AvatarPet(
                                state: state,
                                plantId: plant.id,
                                mood: mood,
                                size: 120,
                                windy: windSwayApplies(
                                  mood,
                                  state.weather?.windKmh ?? 0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                plant.name,
                                style: pixelStyle(size: 10),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              DueBadge(plant: plant, nowUtc: now),
                              const Spacer(),
                              if (needsWater)
                                SizedBox(
                                  width: double.infinity,
                                  child: PixelButton(
                                    label: 'Water',
                                    onPressed: () =>
                                        _water(context, plant.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  PixelButton(
                    label: 'Adopt another plant',
                    color: PlantColors.leaf,
                    onPressed: () => _openAdopt(context),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAdopt(BuildContext context) async {
    final navigator = Navigator.of(context);
    await state.sfx.click();
    await navigator.push(
      MaterialPageRoute(builder: (_) => AdoptScreen(state: state)),
    );
  }
}
