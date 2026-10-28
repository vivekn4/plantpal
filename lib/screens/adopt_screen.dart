import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/plant.dart';
import '../models/species.dart';
import '../services/app_state.dart';
import '../services/pet_state_resolver.dart';
import '../services/pixelate.dart';
import '../services/watering.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_pet.dart';

/// Adopt flow, 3 steps and no more: photo -> name + species ->
/// watered? + soil? -> pet reveal. Back is always available and
/// nothing is lost going back a step.
class AdoptScreen extends StatefulWidget {
  const AdoptScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AdoptScreen> createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  int _step = 0;
  Uint8List? _photoBytes;
  Uint8List? _avatarBytes;
  String? _photoError;
  final _nameController = TextEditingController();
  String _speciesId = speciesTable.first.id;
  bool _justWatered = true;
  SoilFeel _soil = SoilFeel.moist;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      // Cap the picked photo at 1200px on its long side: the stored
      // photo is capped at 900px and the avatar at 48px, so anything
      // larger only costs decode time and memory, never quality the
      // app can show. One decode then produces avatar + stored photo.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final processed = processPhotoForAdopt(bytes);
      setState(() {
        _photoBytes = processed.photo;
        _avatarBytes = processed.avatar;
        _photoError = processed.avatar == null
            ? 'That photo could not be read. Try another one.'
            : null;
      });
    } catch (_) {
      setState(() {
        _photoError =
            'The camera or gallery is not available here. Try the other option.';
      });
    }
  }

  bool get _canContinuePhoto => _photoBytes != null && _avatarBytes != null;

  bool get _canContinueName => _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final now = DateTime.now().toUtc();
    final species = speciesById(_speciesId);
    final plant = Plant(
      id: now.millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      speciesId: _speciesId,
      intervalDays: species.defaultIntervalDays,
      createdUtc: now,
      lastWateredUtc: _justWatered ? now : null,
      firstDueUtc: _justWatered
          ? null
          : firstDueFromSetup(
              setupUtc: now,
              intervalDays: species.defaultIntervalDays,
              soil: _soil,
            ),
      wateredHistoryUtc: _justWatered ? [now] : const [],
      hasPhoto: _photoBytes != null,
      hasAvatar: _avatarBytes != null,
    );
    if (_photoBytes != null) {
      await widget.state.photos.savePhoto(plant.id, _photoBytes!);
    }
    if (_avatarBytes != null) {
      await widget.state.photos.saveAvatar(plant.id, _avatarBytes!);
    }
    final ok = await widget.state.addPlant(plant);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That did not save. Try again.')),
      );
      return;
    }
    await widget.state.sfx.sparkle();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Adopt a plant',
          style: pixelStyle(size: 13, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Step ${_step + 1} of 4',
              style: pixelStyle(size: 11),
            ),
            const SizedBox(height: 16),
            if (_step == 0) _photoStep(),
            if (_step == 1) _nameStep(),
            if (_step == 2) _careStep(),
            if (_step == 3) _revealStep(),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: PixelButton(
                      label: 'Back',
                      color: PlantColors.soil,
                      onPressed: () => setState(() => _step--),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: _step == 3
                      ? PixelButton(
                          label: _saving ? 'Saving…' : 'Keep this pet',
                          onPressed: _saving ? null : _save,
                        )
                      : PixelButton(
                          label: 'Next',
                          onPressed: _nextEnabled()
                              ? () => setState(() => _step++)
                              : null,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _nextEnabled() {
    if (_step == 0) return _canContinuePhoto;
    if (_step == 1) return _canContinueName;
    return true;
  }

  Widget _photoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'First, a photo of your plant.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'It stays on this device. PlantPal turns it into a pixel pet.',
        ),
        const SizedBox(height: 16),
        if (_photoBytes != null) ...[
          Center(
            child: Image.memory(_photoBytes!, height: 220, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tip: a brighter photo with the plant filling the frame '
            'makes a clearer pet.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
        if (_photoError != null) ...[
          const SizedBox(height: 8),
          Text(_photoError!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        PixelButton(
          label: 'Take a photo',
          color: PlantColors.leaf,
          onPressed: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        PixelButton(
          label: 'Choose from gallery',
          onPressed: () => _pick(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _nameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What is its name?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Plant name',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Text('What kind is it?'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _speciesId,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: speciesTable
              .map(
                (species) => DropdownMenuItem(
                  value: species.id,
                  child: Text(species.commonName),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _speciesId = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          speciesById(_speciesId).careNote,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _careStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Two quick questions.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('Did you just water it?'),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Yes')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: {_justWatered},
          onSelectionChanged: (selection) {
            setState(() => _justWatered = selection.first);
          },
        ),
        const SizedBox(height: 20),
        const Text('How does the soil feel right now?'),
        const SizedBox(height: 8),
        SegmentedButton<SoilFeel>(
          segments: const [
            ButtonSegment(value: SoilFeel.dry, label: Text('Dry')),
            ButtonSegment(value: SoilFeel.moist, label: Text('Moist')),
            ButtonSegment(value: SoilFeel.wet, label: Text('Wet')),
          ],
          selected: {_soil},
          onSelectionChanged: (selection) {
            setState(() => _soil = selection.first);
          },
        ),
        const SizedBox(height: 12),
        if (!_justWatered)
          const Text(
            'No problem. The first reminder will be an estimate until '
            "you tap 'I watered it' for real.",
            style: TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  Widget _revealStep() {
    return Column(
      children: [
        const Text(
          'Meet your new pet!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Center(
          child: PixelPet(
            mood: PetMood.happy,
            avatarBytes: _avatarBytes,
            size: 220,
            celebrating: true,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text.trim(),
          style: pixelStyle(size: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${speciesById(_speciesId).commonName} · water every '
          '${speciesById(_speciesId).defaultIntervalDays} days to start',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
