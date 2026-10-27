import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Base64 photo storage for web, where there is no documents directory.
/// Same contract as the mobile implementation; bytes still never leave
/// the device.
class PhotoStorage {
  PhotoStorage(this._prefs);

  final SharedPreferences _prefs;

  Future<void> savePhoto(String plantId, Uint8List bytes) async {
    await _prefs.setString('photo_$plantId', base64Encode(bytes));
  }

  Future<void> saveAvatar(String plantId, Uint8List bytes) async {
    await _prefs.setString('avatar_$plantId', base64Encode(bytes));
  }

  Future<Uint8List?> readPhoto(String plantId) async {
    final raw = _prefs.getString('photo_$plantId');
    if (raw == null) return null;
    return base64Decode(raw);
  }

  Future<Uint8List?> readAvatar(String plantId) async {
    final raw = _prefs.getString('avatar_$plantId');
    if (raw == null) return null;
    return base64Decode(raw);
  }

  Future<void> deleteAll(String plantId) async {
    await _prefs.remove('photo_$plantId');
    await _prefs.remove('avatar_$plantId');
  }

  SharedPreferences get prefs => _prefs;
}
