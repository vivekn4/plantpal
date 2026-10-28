import 'dart:convert';
import 'dart:typed_data';

import '../models/plant.dart';
import 'plant_store.dart';

/// Local backup, on purpose: no cloud, no account, no file host.
/// WaterMe — the open-source Flutter plant app — does backup and
/// restore the same way: a file the user keeps themselves, not a
/// server copy. PlantPal's version is text the user can copy and
/// paste, so it works identically on Android and on web, with no
/// new dependency and no platform file picker to get wrong.
///
/// Format (version 1, plain JSON):
///   {
///     "format": "plantpal-backup",
///     "version": 1,
///     "exportedAtUtc": "2026-10-27T…Z",
///     "settings": {"soundOn": true, "useLocation": false},
///     "plants": [ <Plant JSON>, … ]
///   }
///
/// Each plant object may also carry "avatarBase64": the 48px pixel
/// pet, base64-encoded. Avatars are tiny (a few kilobytes), so they
/// fit in a copied backup. Original photos are NOT in the backup:
/// a 900px photo per plant would turn a backup into megabytes of
/// text that no one can paste reliably. After a restore, pets look
/// the same, but the original photo on the plant screen is gone —
/// the imported plant's hasPhoto is set to false so the app never
/// pretends a photo is there. That limit is stated in the UI, not
/// buried.
///
/// Import replaces the current shelf, after a preview step that
/// shows the plant count and names. Replacing (not merging) is
/// what "restore" means: a plant deleted before the backup stays
/// deleted, and a plant edited after the backup goes back to the
/// backed-up version. Nothing is deleted until the backup has
/// fully validated, so a bad paste can never wipe the shelf.
const String backupFormat = 'plantpal-backup';
const int backupVersion = 1;

/// What a backup contains, after validation, before anything is
/// written. The UI previews this; AppState applies it.
class BackupData {
  const BackupData({
    required this.plants,
    required this.avatars,
    required this.settings,
    required this.exportedAtUtc,
  });

  final List<Plant> plants;

  /// Avatar bytes by plant id, only where the backup carried one.
  final Map<String, Uint8List> avatars;
  final Settings settings;
  final DateTime? exportedAtUtc;
}

/// Build a backup document from the current shelf.
String buildBackupJson({
  required List<Plant> plants,
  required Map<String, Uint8List?> avatars,
  required Settings settings,
  required DateTime exportedAtUtc,
}) {
  final plantJson = plants.map((plant) {
    final json = plant.toJson();
    final avatar = avatars[plant.id];
    if (avatar != null) {
      json['avatarBase64'] = base64Encode(avatar);
    }
    return json;
  }).toList();
  return jsonEncode({
    'format': backupFormat,
    'version': backupVersion,
    'exportedAtUtc': exportedAtUtc.toIso8601String(),
    'settings': settings.toJson(),
    'plants': plantJson,
  });
}

/// Parse and validate a backup document. Returns null when the
/// text is not a PlantPal backup at all, or when a plant in it
/// cannot be read — in both cases the caller keeps the current
/// shelf untouched and shows the reason instead.
///
/// Lenient where it is safe to be: a missing settings block falls
/// back to defaults, a bad avatar for one plant drops just that
/// avatar (the plant still imports), and duplicate plant ids keep
/// the first copy. Strict where it matters: wrong format, wrong
/// version, plants not a list, or a plant with no id all fail.
BackupData? parseBackup(String text) {
  try {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['format'] != backupFormat) return null;
    if (decoded['version'] != backupVersion) return null;
    final rawPlants = decoded['plants'];
    if (rawPlants is! List) return null;

    Settings settings = const Settings();
    final rawSettings = decoded['settings'];
    if (rawSettings is Map<String, dynamic>) {
      try {
        settings = Settings.fromJson(rawSettings);
      } catch (_) {
        settings = const Settings();
      }
    }

    DateTime? exportedAt;
    final rawExported = decoded['exportedAtUtc'];
    if (rawExported is String) {
      final parsed = DateTime.tryParse(rawExported);
      if (parsed != null) {
        exportedAt = parsed.isUtc ? parsed : parsed.toUtc();
      }
    }

    final plants = <Plant>[];
    final avatars = <String, Uint8List>{};
    final seenIds = <String>{};
    for (final raw in rawPlants) {
      if (raw is! Map<String, dynamic>) return null;
      final plant = Plant.fromJson(raw);
      if (plant.id.isEmpty) return null;
      if (!seenIds.add(plant.id)) continue;
      final rawAvatar = raw['avatarBase64'];
      if (rawAvatar is String && rawAvatar.isNotEmpty) {
        try {
          avatars[plant.id] = base64Decode(rawAvatar);
        } catch (_) {
          // Bad avatar: plant imports without it, not a failure.
        }
      }
      // Original photos are never in a backup, so hasPhoto must
      // not survive a restore — otherwise the plant screen would
      // claim a photo that is not on this device.
      plants.add(
        plant.copyWith(
          hasPhoto: false,
          hasAvatar: avatars.containsKey(plant.id),
        ),
      );
    }
    return BackupData(
      plants: plants,
      avatars: avatars,
      settings: settings,
      exportedAtUtc: exportedAt,
    );
  } catch (_) {
    return null;
  }
}

/// One-line preview for the import confirmation step, e.g.
/// "3 plants: Fern, Pothos, Snake plant".
String backupPreview(BackupData data) {
  if (data.plants.isEmpty) return '0 plants';
  final names = data.plants.map((p) => p.name).join(', ');
  return '${data.plants.length} '
      '${data.plants.length == 1 ? 'plant' : 'plants'}: $names';
}
