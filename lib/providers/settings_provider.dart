import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  double _fontScale = 1.0;

  // Основное (постоянное) BLE-устройство, выбранное пользователем на
  // экране настроек. Сохраняется во "временной" локальной базе (таблица
  // settings) и используется для автоматического подключения при
  // следующих запусках приложения — без повторного ручного поиска.
  String? _primaryDeviceId;
  String? _primaryDeviceName;

  double get fontScale => _fontScale;
  String? get primaryDeviceId => _primaryDeviceId;
  String? get primaryDeviceName => _primaryDeviceName;
  bool get hasPrimaryDevice => _primaryDeviceId != null && _primaryDeviceId!.isNotEmpty;

  Future<void> load() async {
    final v = await _db.getSetting('fontScale');
    if (v != null) {
      _fontScale = double.tryParse(v) ?? 1.0;
    }

    _primaryDeviceId = await _db.getSetting('primaryDeviceId');
    _primaryDeviceName = await _db.getSetting('primaryDeviceName');

    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.6, 2.0);
    await _db.saveSetting('fontScale', _fontScale.toString());
    notifyListeners();
  }

  // Запомнить устройство как основное. Вызывается после успешного
  // подключения к устройству, выбранному пользователем на экране настроек
  // из списка найденных по имени (TARGET_DEVICE_NAMES) устройств.
  Future<void> setPrimaryDevice(String remoteId, String name) async {
    _primaryDeviceId = remoteId;
    _primaryDeviceName = name;
    await _db.saveSetting('primaryDeviceId', remoteId);
    await _db.saveSetting('primaryDeviceName', name);
    notifyListeners();
  }

  // "Забыть" сохранённое основное устройство — например, чтобы выбрать
  // другой концентратор.
  Future<void> clearPrimaryDevice() async {
    _primaryDeviceId = null;
    _primaryDeviceName = null;
    await _db.deleteSetting('primaryDeviceId');
    await _db.deleteSetting('primaryDeviceName');
    notifyListeners();
  }
}
