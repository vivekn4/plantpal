import 'package:flutter/material.dart';

import '../models/plant.dart';
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

/// How the shelf is ordered. Due is the default the app shipped
/// with (most urgent first); name and newest are the two orders
/// other plant apps offer, and both are just a re-sort of the
/// same plants — no new data, no new storage.
enum HomeSort { due, name, newest }

/// The pet shelf: a grid of pets, each with a name, a due badge in
/// plain words, and a one-tap water button on pets that need it.
///
/// Now also: search by name, sort, and a "coming up this week"
/// list — the three shelf features every other plant app has, and
/// all three are derived from plants already on the device.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  HomeSort _sort = HomeSort.due;

  AppState get state => widget.state;

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
        final allPlants = state.plants;
        final now = DateTime.now().toUtc();
        final query = _query.trim().toLowerCase();
        var plants = query.isEmpty
            ? allPlants
            : allPlants
                .where((p) => p.name.toLowerCase().contains(query))
                .toList();
        if (_sort == HomeSort.name) {
          plants = [...plants]
            ..sort(
              (a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
        } else if (_sort == HomeSort.newest) {
          plants = [...plants]
            ..sort((a, b) => b.createdUtc.compareTo(a.createdUtc));
        }
        // Coming up: plants due within the next 7 days that are
        // not already overdue (overdue pets already shout from
        // the shelf). Shown only when not searching, so search
        // results are never mixed with a week-ahead list.
        final List<Plant> upcoming = query.isEmpty
            ? allPlants.where((plant) {
                final status = statusAt(plant, now);
                if (status == WateringStatus.overdue) return false;
                return nextDue(plant).difference(now).inDays <= 7;
              }).toList()
            : [];
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
                if (allPlants.isEmpty) ...[
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
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search plants',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Sort: '),
                      const SizedBox(width: 8),
                      DropdownButton<HomeSort>(
                        value: _sort,
                        items: const [
                          DropdownMenuItem(
                            value: HomeSort.due,
                            child: Text('Due first'),
                          ),
                          DropdownMenuItem(
                            value: HomeSort.name,
                            child: Text('Name'),
                          ),
                          DropdownMenuItem(
                            value: HomeSort.newest,
                            child: Text('Newest'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sort = value);
                          }
                        },
                      ),
                    ],
                  ),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Coming up this week',
                      style: pixelStyle(size: 11),
                    ),
                    const SizedBox(height: 8),
                    ...upcoming.map(
                      (plant) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${plant.name} — ${dueBadge(plant, now)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (plants.isEmpty) ...[
                    const Text(
                      'No plants match that search.',
                      textAlign: TextAlign.center,
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
                  ],
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
