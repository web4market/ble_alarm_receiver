import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  double    _fontScale  = 1.0;
  ThemeMode _themeMode  = ThemeMode.dark;
  String?   _primaryDeviceId;
  String?   _primaryDeviceName;
  String?   _language;   // код языка интерфейса ('ru'); null — ещё не выбран
  String?   _pinCode;    // пин-код для сброса до заводских установок
  bool      _loaded = false;

  double    get fontScale        => _fontScale;
  ThemeMode get themeMode        => _themeMode;
  String?   get primaryDeviceId  => _primaryDeviceId;
  String?   get primaryDeviceName => _primaryDeviceName;
  String?   get language         => _language;
  bool get isLoaded       => _loaded;
  bool get needsLanguage  => _language == null;
  bool get needsPin       => _pinCode == null || _pinCode!.isEmpty;

  // Доступные языки интерфейса. Локализация будет позже — пока только русский.
  static const Map<String, String> availableLanguages = {'ru': 'Русский'};

  bool get hasPrimaryDevice =>
      _primaryDeviceId != null && _primaryDeviceId!.isNotEmpty;

  Future<void> load() async {
    final scale = await _db.getSetting('fontScale');
    if (scale != null) _fontScale = double.tryParse(scale) ?? 1.0;

    final theme = await _db.getSetting('themeMode');
    _themeMode = _parseThemeMode(theme);

    _primaryDeviceId   = await _db.getSetting('primaryDeviceId');
    _primaryDeviceName = await _db.getSetting('primaryDeviceName');
    _language          = await _db.getSetting('language');
    _pinCode           = await _db.getSetting('pinCode');

    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _language = code;
    await _db.saveSetting('language', code);
    notifyListeners();
  }

  Future<void> setPinCode(String pin) async {
    _pinCode = pin;
    await _db.saveSetting('pinCode', pin);
    notifyListeners();
  }

  bool checkPin(String pin) => _pinCode != null && _pinCode == pin;

  // Вызывается после того, как ReceiverProvider очистил базу: возвращает
  // значения по умолчанию, и приложение снова начинает с выбора языка.
  void resetToDefaults() {
    _fontScale = 1.0;
    _themeMode = ThemeMode.dark;
    _primaryDeviceId = null;
    _primaryDeviceName = null;
    _language = null;
    _pinCode = null;
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.6, 2.0);
    await _db.saveSetting('fontScale', _fontScale.toString());
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _db.saveSetting('themeMode', _themeModeKey(mode));
    notifyListeners();
  }

  Future<void> setPrimaryDevice(String remoteId, String name) async {
    _primaryDeviceId   = remoteId;
    _primaryDeviceName = name;
    await _db.saveSetting('primaryDeviceId', remoteId);
    await _db.saveSetting('primaryDeviceName', name);
    notifyListeners();
  }

  Future<void> clearPrimaryDevice() async {
    _primaryDeviceId   = null;
    _primaryDeviceName = null;
    await _db.deleteSetting('primaryDeviceId');
    await _db.deleteSetting('primaryDeviceName');
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _themeModeKey(ThemeMode m) => switch (m) {
        ThemeMode.light  => 'light',
        ThemeMode.dark   => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _parseThemeMode(String? s) => switch (s) {
        'light'  => ThemeMode.light,
        'system' => ThemeMode.system,
        _        => ThemeMode.dark,
      };
}
