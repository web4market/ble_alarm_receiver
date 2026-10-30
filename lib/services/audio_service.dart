import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Основной плеер — сирена тревоги и предупреждения (вскрытие, разряд).
  AudioPlayer? _player;
  // Отдельный плеер коротких сигналов (потеря связи, питание, подключение),
  // чтобы они не обрывали сирену тревоги.
  AudioPlayer? _fx;

  static const _alarm     = 'audio/sfx/alarm-siren.mp3';
  static const _warning   = 'audio/sfx/seat-belt-unfastened-car-alarm.mp3';
  static const _btLost    = 'audio/sfx/beep-bt-lost.wav';
  static const _power     = 'audio/sfx/beep-power.wav';
  static const _connected = 'audio/sfx/chime-connected.wav';

  // Аудио-поток Alarm: звучит даже в режиме «без звука» на Android
  static final _alarmContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.gain,
      usageType: AndroidUsageType.alarm,
      contentType: AndroidContentType.sonification,
      isSpeakerphoneOn: true,
      stayAwake: true,
    ),
  );

  // Короткие сигналы не забирают аудиофокус у сирены
  static final _fxContext = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.alarm,
      contentType: AndroidContentType.sonification,
      isSpeakerphoneOn: true,
    ),
  );

  Future<AudioPlayer> _main() async {
    if (_player != null) return _player!;
    _player = AudioPlayer();
    try {
      await _player!.setAudioContext(_alarmContext);
    } catch (e) {
      debugPrint('AudioService: setAudioContext failed: $e');
    }
    return _player!;
  }

  Future<AudioPlayer> _fxPlayer() async {
    if (_fx != null) return _fx!;
    _fx = AudioPlayer();
    try {
      await _fx!.setAudioContext(_fxContext);
    } catch (e) {
      debugPrint('AudioService: fx setAudioContext failed: $e');
    }
    return _fx!;
  }

  Future<void> playAlarm() async {
    try {
      final p = await _main();
      await p.stop();
      await p.play(AssetSource(_alarm));
    } catch (e) {
      debugPrint('AudioService: playAlarm error: $e');
    }
  }

  Future<void> playWarning() async {
    try {
      final p = await _main();
      await p.stop();
      await p.play(AssetSource(_warning));
    } catch (e) {
      debugPrint('AudioService: playWarning error: $e');
    }
  }

  Future<void> _playFx(String asset) async {
    try {
      final p = await _fxPlayer();
      await p.stop();
      await p.play(AssetSource(asset));
    } catch (e) {
      debugPrint('AudioService: fx error: $e');
    }
  }

  /// Короткий сигнал потери связи с BT (повторяется каждые 10 с)
  Future<void> playBtLostBeep() => _playFx(_btLost);

  /// Сигнал работы планшета от аккумулятора (каждую минуту)
  Future<void> playPowerBeep() => _playFx(_power);

  /// Мелодичный сигнал: связь с BT установлена
  Future<void> playConnected() => _playFx(_connected);

  /// Короткий сигнал общего назначения (низкий заряд планшета и т.п.)
  Future<void> playShortBeep() => _playFx(_btLost);

  /// Остановить сирену/предупреждение (короткие сигналы доигрывают сами)
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
    _fx?.dispose();
    _fx = null;
  }
}
