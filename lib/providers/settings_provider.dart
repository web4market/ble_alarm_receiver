import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  double _fontScale = 1.0;

  double get fontScale => _fontScale;

  Future<void> load() async {
    final v = await _db.getSetting('fontScale');
    if (v != null) {
      _fontScale = double.tryParse(v) ?? 1.0;
      notifyListeners();
    }
  }

  Future<void> setFontScale(double v) async {
    _fontScale = v.clamp(0.6, 2.0);
    await _db.saveSetting('fontScale', _fontScale.toString());
    notifyListeners();
  }
}
