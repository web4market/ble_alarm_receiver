import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;

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
