import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;
  int _playToken = 0;

  static const _alarm   = 'audio/sfx/alarm-siren.mp3';
  static const _warning = 'audio/sfx/seat-belt-unfastened-car-alarm.mp3';

  // Инициализация при первом вызове — устанавливаем аудио-поток Alarm
  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    _player = AudioPlayer();

    // Аудио-поток Alarm: звучит даже в режиме «без звука» на Android
    try {
      await _player!.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.gain,
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          isSpeakerphoneOn: true,
          stayAwake: true,
        ),
      ));
    } catch (e) {
      debugPrint('AudioService: setAudioContext failed: $e');
    }
  }

  Future<void> playAlarm() async {
    try {
      await _ensurePlayer();
      await _player!.stop();
      _playToken++;
      await _player!.play(AssetSource(_alarm));
      debugPrint('AudioService: alarm played');
    } catch (e) {
      debugPrint('AudioService: playAlarm error: $e');
    }
  }

  Future<void> playWarning() async {
    try {
      await _ensurePlayer();
      await _player!.stop();
      await _player!.play(AssetSource(_warning));
      debugPrint('AudioService: warning played');
    } catch (e) {
      debugPrint('AudioService: playWarning error: $e');
    }
  }

  // Кратковременный сигнал (потеря связи с BT, низкий заряд планшета):
  // тот же звук предупреждения, но обрывается через [duration].
  Future<void> playShortBeep({Duration duration = const Duration(milliseconds: 1500)}) async {
    await playWarning();
    final token = ++_playToken;
    // Не обрываем звук, если за это время началась тревога/другой сигнал
    Future.delayed(duration, () { if (token == _playToken) stop(); });
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('AudioService: stop error: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
