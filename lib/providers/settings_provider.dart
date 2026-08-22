import 'package:flutter/material.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  double    _fontScale  = 1.0;
  ThemeMode _themeMode  = ThemeMode.dark;
  String?   _primaryDeviceId;
  String?   _primaryDeviceName;

  double    get fontScale        => _fontScale;
  ThemeMode get themeMode        => _themeMode;
  String?   get primaryDeviceId  => _primaryDeviceId;
  String?   get primaryDeviceName => _primaryDeviceName;
  bool get hasPrimaryDevice =>
      _primaryDeviceId != null && _primaryDeviceId!.isNotEmpty;

  Future<void> load() async {
    final scale = await _db.getSetting('fontScale');
    if (scale != null) _fontScale = double.tryParse(scale) ?? 1.0;

    final theme = await _db.getSetting('themeMode');
    _themeMode = _parseThemeMode(theme);

    _primaryDeviceId   = await _db.getSetting('primaryDeviceId');
    _primaryDeviceName = await _db.getSetting('primaryDeviceName');

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
