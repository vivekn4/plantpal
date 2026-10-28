import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/care_task.dart';
import 'package:plantpal/models/plant.dart';
import 'package:plantpal/services/backup.dart';
import 'package:plantpal/services/plant_store.dart';

Plant _fern() {
  return Plant(
    id: 'p1',
    name: 'Fern',
    speciesId: 'fern',
    intervalDays: 7,
    createdUtc: DateTime.utc(2026, 10, 1),
    lastWateredUtc: DateTime.utc(2026, 10, 20),
    wateredHistoryUtc: [DateTime.utc(2026, 10, 20)],
    hasPhoto: true,
    hasAvatar: true,
    note: 'Likes the east window.',
    careTasks: [
      CareTask(
        kind: CareTaskKind.fertilize,
        intervalDays: 30,
        nextDueUtc: DateTime.utc(2026, 11, 1),
      ),
    ],
  );
}

void main() {
  test('export then parse round-trips plants, tasks, notes, settings', () {
    final avatar = Uint8List.fromList([1, 2, 3, 4]);
    final text = buildBackupJson(
      plants: [_fern()],
      avatars: {'p1': avatar},
      settings: const Settings(soundOn: false, useLocation: true),
      exportedAtUtc: DateTime.utc(2026, 10, 27, 12),
    );
    final data = parseBackup(text);
    expect(data, isNotNull);
    expect(data!.plants.length, 1);
    expect(data.plants.first.name, 'Fern');
    expect(data.plants.first.note, 'Likes the east window.');
    expect(data.plants.first.careTasks.length, 1);
    expect(data.plants.first.careTasks.first.kind, CareTaskKind.fertilize);
    expect(data.settings.soundOn, isFalse);
    expect(data.settings.useLocation, isTrue);
    expect(data.avatars['p1'], avatar);
    expect(backupPreview(data), '1 plant: Fern');
  });

  test('restored plants never claim an original photo', () {
    final text = buildBackupJson(
      plants: [_fern()],
      avatars: {},
      settings: const Settings(),
      exportedAtUtc: DateTime.utc(2026, 10, 27, 12),
    );
    final data = parseBackup(text)!;
    // The source plant had hasPhoto true, but original photos are
    // never in a backup, so the restored plant must say false.
    expect(data.plants.first.hasPhoto, isFalse);
    expect(data.plants.first.hasAvatar, isFalse);
  });

  test('parse rejects wrong format, wrong version, and bad plants', () {
    expect(parseBackup('not json at all'), isNull);
    expect(parseBackup(jsonEncode({'format': 'other', 'version': 1, 'plants': []})), isNull);
    expect(parseBackup(jsonEncode({'format': 'plantpal-backup', 'version': 2, 'plants': []})), isNull);
    expect(parseBackup(jsonEncode({'format': 'plantpal-backup', 'version': 1, 'plants': 'nope'})), isNull);
    expect(
      parseBackup(jsonEncode({
        'format': 'plantpal-backup',
        'version': 1,
        'plants': [
          {'name': 'No id here'},
        ],
      })),
      isNull,
    );
  });

  test('parse is lenient about settings and avatars, strict about ids', () {
    final text = jsonEncode({
      'format': 'plantpal-backup',
      'version': 1,
      'plants': [
        {
          ..._fern().toJson(),
          'avatarBase64': '!!!not-base64!!!',
        },
        _fern().toJson(),
      ],
    });
    final data = parseBackup(text)!;
    // Duplicate id: first copy kept, second dropped.
    expect(data.plants.length, 1);
    // Bad avatar: plant still imports, just without an avatar.
    expect(data.avatars, isEmpty);
    expect(data.plants.first.hasAvatar, isFalse);
    // Missing settings: defaults, not a failure.
    expect(data.settings.soundOn, isTrue);
  });

  test('empty backup parses as zero plants', () {
    final text = buildBackupJson(
      plants: [],
      avatars: {},
      settings: const Settings(),
      exportedAtUtc: DateTime.utc(2026, 10, 27, 12),
    );
    final data = parseBackup(text)!;
    expect(data.plants, isEmpty);
    expect(backupPreview(data), '0 plants');
  });
}
