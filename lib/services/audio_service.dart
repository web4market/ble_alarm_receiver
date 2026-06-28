import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  static const _alarm   = 'audio/sfx/alarm-siren.mp3';
  static const _warning = 'audio/sfx/seat-belt-unfastened-car-alarm.mp3';

  Future<void> playAlarm() => _play(_alarm);
  Future<void> playWarning() => _play(_warning);
  Future<void> stop() => _player.stop();

  Future<void> _play(String asset) async {
    await _player.stop();
    await _player.play(AssetSource(asset));
  }

  void dispose() => _player.dispose();
}
