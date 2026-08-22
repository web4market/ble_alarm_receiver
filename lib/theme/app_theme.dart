import 'package:flutter/material.dart';

// Accent colours are the same in both themes.
const kAccBlue  = Color(0xFF4FC3F7);
const kAccGreen = Color(0xFF34A853);
const kAccRed   = Color(0xFFEA4335);
const kAccAmber = Color(0xFFFBBC04);

// ── Custom colour tokens ──────────────────────────────────────────────────────

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.surface,
    required this.border,
    required this.text1,
    required this.text2,
    required this.tileBgNormal,
    required this.tileBgAlarm,
    required this.tileBgDisarmed,
    required this.tileBgOff,
    required this.tileBgBattery,
    required this.tileBorderNormal,
    required this.tileBorderDisarmed,
    required this.tileText,
    required this.tileTextDim,
    required this.detailBtnArm,
    required this.detailBtnDisarm,
    required this.detailBtnInactive,
    required this.detailBtnInactiveBorder,
    required this.detailBtnInactiveText,
    required this.eventRowDivider,
  });

  final Color page;
  final Color surface;
  final Color border;
  final Color text1;
  final Color text2;
  // Detector tiles
  final Color tileBgNormal;
  final Color tileBgAlarm;
  final Color tileBgDisarmed;
  final Color tileBgOff;
  final Color tileBgBattery;
  final Color tileBorderNormal;
  final Color tileBorderDisarmed;
  final Color tileText;
  final Color tileTextDim;
  // Detector detail action buttons
  final Color detailBtnArm;
  final Color detailBtnDisarm;
  final Color detailBtnInactive;
  final Color detailBtnInactiveBorder;
  final Color detailBtnInactiveText;
  // Event log row separator
  final Color eventRowDivider;

  // ── Palettes ────────────────────────────────────────────────────────────────

  static const dark = AppColors(
    page:    Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    border:  Color(0xFF2D3748),
    text1:   Color(0xFFD0DDD8),
    text2:   Color(0xFF6A8090),
    tileBgNormal:        Color(0xFF0A2010),
    tileBgAlarm:         Color(0xFF2A0808),
    tileBgDisarmed:      Color(0xFF181818),
    tileBgOff:           Color(0xFF111111),
    tileBgBattery:       Color(0xFF2A1A06),
    tileBorderNormal:    Color(0xFF2A6A2A),
    tileBorderDisarmed:  Color(0xFF383838),
    tileText:            Color(0xFFD0DDD8),
    tileTextDim:         Color(0xFF5A7060),
    detailBtnArm:              Color(0xFF1A5A1A),
    detailBtnDisarm:           Color(0xFF6A2A00),
    detailBtnInactive:         Color(0xFF1A1A1A),
    detailBtnInactiveBorder:   Color(0xFF2A2A2A),
    detailBtnInactiveText:     Color(0xFF3A3A3A),
    eventRowDivider:     Color(0xFF1A2030),
  );

  static const light = AppColors(
    page:    Color(0xFFF0F2F5),
    surface: Color(0xFFFFFFFF),
    border:  Color(0xFFDDE2EA),
    text1:   Color(0xFF1A2332),
    text2:   Color(0xFF7A8899),
    tileBgNormal:        Color(0xFFEDF7ED),
    tileBgAlarm:         Color(0xFFFDEDED),
    tileBgDisarmed:      Color(0xFFF5F5F5),
    tileBgOff:           Color(0xFFEAEAEA),
    tileBgBattery:       Color(0xFFFFF8E1),
    tileBorderNormal:    Color(0xFF5EAD5E),
    tileBorderDisarmed:  Color(0xFFCCCCCC),
    tileText:            Color(0xFF1A2332),
    tileTextDim:         Color(0xFF8AAFA0),
    detailBtnArm:              Color(0xFFDCF0DC),
    detailBtnDisarm:           Color(0xFFFFF0DC),
    detailBtnInactive:         Color(0xFFF0F0F0),
    detailBtnInactiveBorder:   Color(0xFFDDDDDD),
    detailBtnInactiveText:     Color(0xFFAAAAAA),
    eventRowDivider:     Color(0xFFEEF0F4),
  );

  // ── ThemeExtension boilerplate ───────────────────────────────────────────────

  @override
  AppColors copyWith({
    Color? page, Color? surface, Color? border, Color? text1, Color? text2,
    Color? tileBgNormal, Color? tileBgAlarm, Color? tileBgDisarmed,
    Color? tileBgOff, Color? tileBgBattery,
    Color? tileBorderNormal, Color? tileBorderDisarmed,
    Color? tileText, Color? tileTextDim,
    Color? detailBtnArm, Color? detailBtnDisarm,
    Color? detailBtnInactive, Color? detailBtnInactiveBorder,
    Color? detailBtnInactiveText, Color? eventRowDivider,
  }) => AppColors(
    page:    page    ?? this.page,
    surface: surface ?? this.surface,
    border:  border  ?? this.border,
    text1:   text1   ?? this.text1,
    text2:   text2   ?? this.text2,
    tileBgNormal:       tileBgNormal       ?? this.tileBgNormal,
    tileBgAlarm:        tileBgAlarm        ?? this.tileBgAlarm,
    tileBgDisarmed:     tileBgDisarmed     ?? this.tileBgDisarmed,
    tileBgOff:          tileBgOff          ?? this.tileBgOff,
    tileBgBattery:      tileBgBattery      ?? this.tileBgBattery,
    tileBorderNormal:   tileBorderNormal   ?? this.tileBorderNormal,
    tileBorderDisarmed: tileBorderDisarmed ?? this.tileBorderDisarmed,
    tileText:           tileText           ?? this.tileText,
    tileTextDim:        tileTextDim        ?? this.tileTextDim,
    detailBtnArm:             detailBtnArm             ?? this.detailBtnArm,
    detailBtnDisarm:          detailBtnDisarm          ?? this.detailBtnDisarm,
    detailBtnInactive:        detailBtnInactive        ?? this.detailBtnInactive,
    detailBtnInactiveBorder:  detailBtnInactiveBorder  ?? this.detailBtnInactiveBorder,
    detailBtnInactiveText:    detailBtnInactiveText    ?? this.detailBtnInactiveText,
    eventRowDivider:    eventRowDivider    ?? this.eventRowDivider,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      page:    l(page,    other.page),
      surface: l(surface, other.surface),
      border:  l(border,  other.border),
      text1:   l(text1,   other.text1),
      text2:   l(text2,   other.text2),
      tileBgNormal:       l(tileBgNormal,       other.tileBgNormal),
      tileBgAlarm:        l(tileBgAlarm,        other.tileBgAlarm),
      tileBgDisarmed:     l(tileBgDisarmed,     other.tileBgDisarmed),
      tileBgOff:          l(tileBgOff,          other.tileBgOff),
      tileBgBattery:      l(tileBgBattery,      other.tileBgBattery),
      tileBorderNormal:   l(tileBorderNormal,   other.tileBorderNormal),
      tileBorderDisarmed: l(tileBorderDisarmed, other.tileBorderDisarmed),
      tileText:           l(tileText,           other.tileText),
      tileTextDim:        l(tileTextDim,        other.tileTextDim),
      detailBtnArm:            l(detailBtnArm,            other.detailBtnArm),
      detailBtnDisarm:         l(detailBtnDisarm,         other.detailBtnDisarm),
      detailBtnInactive:       l(detailBtnInactive,       other.detailBtnInactive),
      detailBtnInactiveBorder: l(detailBtnInactiveBorder, other.detailBtnInactiveBorder),
      detailBtnInactiveText:   l(detailBtnInactiveText,   other.detailBtnInactiveText),
      eventRowDivider:    l(eventRowDivider,    other.eventRowDivider),
    );
  }
}

// ── ThemeData factories ───────────────────────────────────────────────────────

class AppTheme {
  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.dark.page,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccBlue,
      brightness: Brightness.dark,
      surface: AppColors.dark.surface,
    ),
    dividerColor: AppColors.dark.border,
    dialogBackgroundColor: AppColors.dark.surface,
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF161B22)),
    extensions: const [AppColors.dark],
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.light.page,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0288D1),
      brightness: Brightness.light,
      surface: AppColors.light.surface,
    ),
    dividerColor: AppColors.light.border,
    dialogBackgroundColor: AppColors.light.surface,
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFFFFFF)),
    extensions: const [AppColors.light],
  );
}

// Convenience accessor — use inside build(context)
AppColors appColors(BuildContext context) =>
    Theme.of(context).extension<AppColors>()!;
