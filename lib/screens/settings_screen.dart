import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';

/// Settings: location, sound, and honest notes about where data goes
/// (nowhere) and where weather comes from (Open-Meteo, free).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final settings = state.settings;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Settings',
              style: pixelStyle(size: 13, color: Colors.white),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Sounds'),
                subtitle: const Text(
                  'Short blips on taps and watering. Off silences '
                  'everything.',
                ),
                value: settings.soundOn,
                onChanged: (value) async {
                  await state.updateSettings(
                    settings.copyWith(soundOn: value),
                  );
                  if (value) await state.sfx.click();
                },
              ),
              SwitchListTile(
                title: const Text('Use my location for weather'),
                subtitle: Text(state.weatherLocationNote),
                value: settings.useLocation,
                onChanged: (value) async {
                  await state.updateSettings(
                    settings.copyWith(useLocation: value),
                  );
                },
              ),
              const Divider(),
              const ListTile(
                title: Text('Weather'),
                subtitle: Text(
                  'Weather: Open-Meteo, free, no account. If the network '
                  'fails, the pet falls back to time of day and the '
                  'weather badge reads unavailable. Weather never '
                  'changes a watering date.',
                ),
              ),
              const ListTile(
                title: Text('Photos'),
                subtitle: Text(
                  'Your photos and pixel pets stay on this device. '
                  'Nothing is uploaded anywhere. Deleting a plant '
                  'deletes its photo too. Reinstalling without a '
                  'backup loses your pets — there is no cloud copy.',
                ),
              ),
              const ListTile(
                title: Text('About'),
                subtitle: Text(
                  'PlantPal — your plant, as a pixel pet. Android + '
                  'web. No accounts, no ads, no subscriptions.\n'
                  'Pixel font: Press Start 2P (SIL Open Font Licence).\n'
                  'Sounds: short blips synthesized for this app.\n'
                  '— VN',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
