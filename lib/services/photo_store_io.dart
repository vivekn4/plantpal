import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// File-based photo storage for Android (and any dart:io platform).
class PhotoStorage {
  PhotoStorage(this._prefs);

  final SharedPreferences _prefs;

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/plantpal');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> savePhoto(String plantId, Uint8List bytes) async {
    final dir = await _dir();
    await File('${dir.path}/${plantId}_photo.jpg').writeAsBytes(bytes);
  }

  Future<void> saveAvatar(String plantId, Uint8List bytes) async {
    final dir = await _dir();
    await File('${dir.path}/${plantId}_avatar.png').writeAsBytes(bytes);
  }

  Future<Uint8List?> readPhoto(String plantId) async {
    final dir = await _dir();
    final file = File('${dir.path}/${plantId}_photo.jpg');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<Uint8List?> readAvatar(String plantId) async {
    final dir = await _dir();
    final file = File('${dir.path}/${plantId}_avatar.png');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Deleting a plant deletes its photo and avatar too — no orphans.
  Future<void> deleteAll(String plantId) async {
    final dir = await _dir();
    for (final name in ['${plantId}_photo.jpg', '${plantId}_avatar.png']) {
      final file = File('${dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }

  // Kept so the web implementation can share one call shape; unused here.
  SharedPreferences get prefs => _prefs;
}
