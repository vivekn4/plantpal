import 'package:audioplayers/audioplayers.dart';

/// Short original blips, synthesized for this app (assets/sfx/).
/// Every sound is triggered by a tap — never autoplay — and the
/// settings toggle silences all of them (PLAN.md bug 11).
class SfxService {
  SfxService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool enabled = true;

  Future<void> click() => _play('sfx/click.wav');

  Future<void> water() => _play('sfx/bloop.wav');

  Future<void> sparkle() => _play('sfx/sparkle.wav');

  Future<void> _play(String asset) async {
    if (!enabled) return;
    try {
      // Bounded waits: a sound backend that never answers (or a
      // missing platform channel in tests) must never stall a tap.
      await _player.stop().timeout(const Duration(milliseconds: 500));
      await _player
          .play(AssetSource(asset))
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Sound must never break a tap.
    }
  }
}
