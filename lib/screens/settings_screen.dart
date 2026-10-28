import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_state.dart';
import '../services/backup.dart';
import '../theme/app_theme.dart';

/// Settings: location, sound, backup, and honest notes about where
/// data goes (nowhere) and where weather comes from (Open-Meteo,
/// free).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final backup = await state.exportBackup();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export backup'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Copy this text and keep it somewhere safe — a '
                'note, an email to yourself, a file. It holds '
                'your plants, care tasks, notes, and settings, '
                'plus your pixel pets.',
              ),
              const SizedBox(height: 8),
              const Text(
                'It does NOT hold your original photos, so after '
                'a restore your pets will look the same but the '
                'original photo on each plant screen will be gone. '
                'Nothing is uploaded anywhere.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              SelectableText(
                backup,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: backup));
              if (context.mounted) {
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Backup copied. Keep it somewhere safe.'),
                  ),
                );
              }
            },
            child: const Text('Copy backup'),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    BackupData? preview;
    String? error;
    var confirmed = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Import backup'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paste a backup you exported from PlantPal. '
                    'First it is checked, then you confirm — '
                    'importing REPLACES your current plants with '
                    'the backup. Nothing is deleted until the '
                    'backup has fully validated.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Paste backup text here…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'This backup holds ${backupPreview(preview!)}.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Original photos are not in a backup, so '
                      'restored plants will not show an original '
                      'photo. Settings in the backup will also be '
                      'restored.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final parsed = parseBackup(controller.text);
                  setDialogState(() {
                    preview = parsed;
                    error = parsed == null
                        ? 'That does not look like a PlantPal backup. '
                            'Check you pasted the whole text.'
                        : null;
                  });
                },
                child: const Text('Check backup'),
              ),
              if (preview != null)
                TextButton(
                  onPressed: () {
                    confirmed = true;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Replace with this backup'),
                ),
            ],
          );
        },
      ),
    );
    // Capture the text before disposing the controller: reading
    // .text after dispose is not safe, and the import below must
    // use exactly the text that was previewed and confirmed.
    final pasted = controller.text;
    controller.dispose();
    if (!confirmed || !context.mounted) return;
    final count = await state.importBackup(pasted);
    if (!context.mounted) return;
    if (count == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That backup could not be imported. Nothing changed.'),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Restored $count ${count == 1 ? 'plant' : 'plants'}.')),
      );
    }
  }

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
              ListTile(
                title: const Text('Export backup'),
                subtitle: const Text(
                  'Copy your plants, care tasks, notes, settings, '
                  'and pixel pets as text you keep yourself. '
                  'Original photos are not included.',
                ),
                trailing: const Icon(Icons.upload),
                onTap: () => _export(context),
              ),
              ListTile(
                title: const Text('Import backup'),
                subtitle: const Text(
                  'Paste a backup to restore it. This replaces '
                  'your current plants, after a preview.',
                ),
                trailing: const Icon(Icons.download),
                onTap: () => _import(context),
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
                  'deletes its photo too. Export a backup in '
                  'Settings before reinstalling — a backup holds '
                  'your pixel pets, but not your original photos, '
                  'and there is no cloud copy.',
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
