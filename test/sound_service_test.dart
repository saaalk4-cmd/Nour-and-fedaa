import 'package:flutter_test/flutter_test.dart';
import 'package:nourfadaa/core/audio/sound_service.dart';

class _FakePlayer implements SoundPlayer {
  final List<SoundEffect> played = [];
  bool throwOnPlay = false;

  @override
  Future<void> play(SoundEffect effect) async {
    if (throwOnPlay) throw StateError('no audio device');
    played.add(effect);
  }
}

void main() {
  test('plays when enabled and reads the setting only once', () async {
    final player = _FakePlayer();
    var reads = 0;
    final service = SoundService(
      player: player,
      readEnabled: () async {
        reads++;
        return true;
      },
      writeEnabled: (_) async {},
    );
    await service.play(SoundEffect.tap);
    await service.play(SoundEffect.success);
    expect(player.played, [SoundEffect.tap, SoundEffect.success]);
    expect(reads, 1);
  });

  test('is silent when the parent disables sound, and persists the choice', () async {
    final player = _FakePlayer();
    bool? saved;
    final service = SoundService(
      player: player,
      readEnabled: () async => true,
      writeEnabled: (v) async => saved = v,
    );
    await service.setEnabled(false);
    await service.play(SoundEffect.levelUp);
    expect(player.played, isEmpty);
    expect(saved, isFalse);

    await service.setEnabled(true);
    await service.play(SoundEffect.correct);
    expect(player.played, [SoundEffect.correct]);
  });

  test('a failing player never throws', () async {
    final player = _FakePlayer()..throwOnPlay = true;
    final service = SoundService(
      player: player,
      readEnabled: () async => true,
      writeEnabled: (_) async {},
    );
    await service.play(SoundEffect.tap);
  });

  test('every effect points at an audio asset', () {
    for (final e in SoundEffect.values) {
      expect(e.asset, startsWith('audio/'));
      expect(e.asset, endsWith('.wav'));
    }
  });
}
