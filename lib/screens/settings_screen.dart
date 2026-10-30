import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/receiver_provider.dart';
import '../services/api_sync_service.dart';
import '../services/app_foreground.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'help_screen.dart';
import 'onboarding_screen.dart';
import 'programming_screen.dart';

// Accent colours are stable across themes.
const _kAccBlue  = kAccBlue;
const _kAccGreen = kAccGreen;
const _kAccRed   = kAccRed;

// ── Общие компоненты ──────────────────────────────────────────────────────────

AppBar _settingsAppBar(BuildContext context, String title, {List<Widget>? actions}) {
  final c = appColors(context);
  return AppBar(
    backgroundColor: c.surface,
    foregroundColor: c.text1,
    titleSpacing: 0,
    title: Text(title,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2)),
    centerTitle: false,
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Divider(height: 1, color: c.border),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _kAccBlue)),
      );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: _kAccBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.text1)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: c.text2)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.text2),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Главный экран настроек
// ════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: _settingsAppBar(context, 'НАСТРОЙКИ'),
      body: Consumer2<SettingsProvider, ReceiverProvider>(
        builder: (ctx, settings, receiver, _) {
          final pct = (settings.fontScale * 100).round();
          final themeName = _themeLabel(settings.themeMode);
          final bleSubtitle = settings.hasPrimaryDevice
              ? settings.primaryDeviceName ?? 'Устройство выбрано'
              : 'Устройство не выбрано';

          return ListView(
            children: [
              _SectionHeader('ИНТЕРФЕЙС'),
              _SettingsRow(
                icon: Icons.text_fields,
                title: 'Экран',
                subtitle: 'Шрифт: $pct%  •  Тема: $themeName',
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const ScreenSettingsPage())),
              ),
              _SectionHeader('ПОДКЛЮЧЕНИЕ'),
              _SettingsRow(
                icon: Icons.bluetooth,
                title: 'Подключение',
                subtitle: bleSubtitle,
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const BluetoothSettingsPage())),
              ),
              _SectionHeader('ИЗВЕЩАТЕЛИ'),
              _SettingsRow(
                icon: Icons.sensors,
                title: 'Программирование извещателей',
                subtitle: 'Запрограммировано: ${receiver.detectors.length}',
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const ProgrammingScreen())),
              ),
              _SectionHeader('УВЕДОМЛЕНИЯ'),
              _SettingsRow(
                icon: Icons.volume_up_outlined,
                title: 'Звук',
                subtitle: receiver.soundEnabled ? 'Включён' : 'Выключен',
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const SoundSettingsPage())),
              ),
              const _AlarmPopupRow(),
              _ServerApiBlock(settings: settings),
              _SectionHeader('ИНФОРМАЦИЯ'),
              _SettingsRow(
                icon: Icons.help_outline,
                title: 'Помощь',
                subtitle: 'Инструкция, поддержка, документация',
                onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const HelpScreen())),
              ),
              _SectionHeader('СИСТЕМА'),
              _SettingsRow(
                icon: Icons.restart_alt,
                title: 'Сбросить данные до заводских установок',
                subtitle: 'Удаляет извещатели, журнал, BT-устройство и настройки',
                onTap: () => _factoryReset(ctx),
              ),
            ],
          );
        },
      ),
    );
  }

  // Сброс до заводских установок — только после ввода пин-кода, заданного
  // при первом запуске. После сброса приложение начинает с выбора языка.
  Future<void> _factoryReset(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final receiver = context.read<ReceiverProvider>();
    final ok = await showPinCheckDialog(
      context,
      title: 'Сброс до заводских установок',
      message: 'Будут удалены все извещатели, журнал событий, выбранное '
          'BT-устройство и настройки. Введите пин-код для подтверждения.',
      okLabel: 'Сбросить',
      destructive: true,
    );
    if (ok != true || !context.mounted) return;

    await receiver.factoryReset();
    settings.resetToDefaults();
    ApiSyncService().reset();
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  static String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.dark   => 'Тёмная',
        ThemeMode.light  => 'Светлая',
        ThemeMode.system => 'Системная',
      };
}

// ════════════════════════════════════════════════════════════════════════════
// Экран → Настройки экрана (шрифт)
// ════════════════════════════════════════════════════════════════════════════

class ScreenSettingsPage extends StatelessWidget {
  const ScreenSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: _settingsAppBar(context, 'ЭКРАН'),
      body: Consumer<SettingsProvider>(
        builder: (ctx, settings, _) {
          final scale = settings.fontScale;
          final pct   = (scale * 100).round();

          return ListView(
            children: [
              // ── Тема ──────────────────────────────────────────────────────
              _SectionHeader('ТЕМА ОФОРМЛЕНИЯ'),
              Container(
                color: c.surface,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: _ThemePicker(settings: settings),
              ),
              Divider(height: 1, color: c.border),

              // ── Шрифт ─────────────────────────────────────────────────────
              _SectionHeader('РАЗМЕР ШРИФТА'),
              Container(
                color: c.surface,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок со значением
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Масштаб текста',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: c.text1)),
                        _pctBadge(pct),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Масштабирует весь текст приложения. 100% — по умолчанию',
                      style: TextStyle(fontSize: 11, color: c.text2),
                    ),
                    const SizedBox(height: 16),

                    // Слайдер
                    SliderTheme(
                      data: SliderTheme.of(ctx).copyWith(
                        activeTrackColor: _kAccBlue,
                        inactiveTrackColor: c.border,
                        thumbColor: _kAccBlue,
                        overlayColor: _kAccBlue.withOpacity(0.15),
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: scale,
                        min: SettingsProvider.minFontScale,
                        max: SettingsProvider.maxFontScale,
                        divisions: 10, // шаг 10%
                        onChanged: settings.setFontScale,
                      ),
                    ),

                    // Кнопки − / пресеты / +
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _stepBtn(ctx, '−', () => settings.setFontScale(scale - 0.1)),
                        // Пресеты ужимаются, если не помещаются (крупный шрифт)
                        Flexible(child: FittedBox(child: Row(children: [
                          _presetBtn(ctx, '50%',  0.5, scale, settings),
                          const SizedBox(width: 6),
                          _presetBtn(ctx, '75%',  0.75, scale, settings),
                          const SizedBox(width: 6),
                          _presetBtn(ctx, '100%', 1.0, scale, settings),
                          const SizedBox(width: 6),
                          _presetBtn(ctx, '125%', 1.25, scale, settings),
                          const SizedBox(width: 6),
                          _presetBtn(ctx, '150%', 1.5, scale, settings),
                        ]))),
                        _stepBtn(ctx, '+', () => settings.setFontScale(scale + 0.1)),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),

              // Превью
              _SectionHeader('ПРЕДПРОСМОТР'),
              Container(
                color: c.surface,
                padding: const EdgeInsets.all(16),
                child: MediaQuery(
                  data: MediaQuery.of(ctx)
                      .copyWith(textScaler: appTextScaler(scale)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.page,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Зона 1  •  L50RA LoRa',
                            style: TextStyle(
                                fontSize: 9, color: c.text2, letterSpacing: 0.4)),
                        const SizedBox(height: 4),
                        Text('ТРЕВОГА',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kAccRed)),
                        Text('ID: 0001  •  Контроль',
                            style: TextStyle(
                                fontSize: 9, color: c.text2)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pctBadge(int pct) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kAccBlue.withOpacity(0.15),
          border: Border.all(color: _kAccBlue.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$pct%',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kAccBlue,
                fontFamily: 'monospace')),
      );

  Widget _stepBtn(BuildContext ctx, String label, VoidCallback onTap) {
    final c = appColors(ctx);
    return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.border.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 18,
                    color: c.text1,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
  }

  Widget _presetBtn(
      BuildContext ctx, String label, double value, double current, SettingsProvider s) {
    final c      = appColors(ctx);
    final active = (current - value).abs() < 0.05;
    return GestureDetector(
      onTap: () => s.setFontScale(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _kAccBlue.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: active ? _kAccBlue : c.border),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? _kAccBlue : c.text2,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Bluetooth → Настройки BLE-устройства
// ════════════════════════════════════════════════════════════════════════════

class BluetoothSettingsPage extends StatelessWidget {
  const BluetoothSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: _settingsAppBar(context, 'ПОДКЛЮЧЕНИЕ'),
      body: Consumer2<SettingsProvider, ReceiverProvider>(
        builder: (ctx, settings, receiver, _) {
          return ListView(
            children: [
              _SectionHeader('ОСНОВНОЕ УСТРОЙСТВО'),

              // Текущее устройство
              Container(
                color: c.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: settings.hasPrimaryDevice
                                ? _kAccGreen.withOpacity(0.12)
                                : c.border.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            settings.hasPrimaryDevice
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_disabled,
                            size: 20,
                            color: settings.hasPrimaryDevice
                                ? _kAccGreen
                                : c.text2,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.hasPrimaryDevice
                                    ? (settings.primaryDeviceName ?? '—')
                                    : 'Устройство не выбрано',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: settings.hasPrimaryDevice
                                        ? c.text1
                                        : c.text2),
                              ),
                              if (settings.hasPrimaryDevice)
                                Text(settings.primaryDeviceId ?? '',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: c.text2,
                                        fontFamily: 'monospace')),
                              if (!settings.hasPrimaryDevice)
                                Text(
                                    'Нажмите «Найти устройство» для поиска',
                                    style: TextStyle(
                                        fontSize: 11, color: c.text2)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Индикатор сканирования
                    if (receiver.isPairingScan) ...[
                      const SizedBox(height: 16),
                      Divider(height: 1, color: c.border),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _kAccBlue),
                          ),
                          const SizedBox(width: 10),
                          Text('Поиск концентраторов...',
                              style: TextStyle(fontSize: 12, color: c.text2)),
                        ],
                      ),
                    ],

                    // Найденные устройства
                    if (receiver.pairingResults.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, color: c.border),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Найдено:',
                            style: TextStyle(fontSize: 10, color: c.text2)),
                      ),
                      const SizedBox(height: 8),
                      ...receiver.pairingResults
                          .map((r) => _FoundDeviceTile(
                                result: r,
                                receiver: receiver,
                                settings: settings,
                              )),
                    ],

                    const SizedBox(height: 16),
                    Divider(height: 1, color: c.border),
                    const SizedBox(height: 16),

                    // Кнопки
                    Row(
                      children: [
                        Expanded(
                          child: _BleActionBtn(
                            label: receiver.isPairingScan
                                ? 'Остановить'
                                : 'Найти устройство',
                            icon: receiver.isPairingScan
                                ? Icons.stop_circle_outlined
                                : Icons.bluetooth_searching,
                            color: receiver.isPairingScan
                                ? _kAccRed
                                : _kAccBlue,
                            onTap: receiver.isPairingScan
                                ? receiver.stopPairingScan
                                : receiver.startPairingScan,
                          ),
                        ),
                        if (settings.hasPrimaryDevice) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BleActionBtn(
                              label: 'Забыть устройство',
                              icon: Icons.delete_outline,
                              color: c.text2,
                              onTap: () {
                                receiver.forgetPrimaryDevice();
                                settings.clearPrimaryDevice();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              _SectionHeader('ИНФОРМАЦИЯ'),
              Container(
                color: c.surface,
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Статус соединения',
                      value: receiver.isConnected ? 'Подключено' : 'Отключено',
                      valueColor: receiver.isConnected ? _kAccGreen : c.text2,
                    ),
                    Divider(height: 1, color: c.border),
                    _InfoRow(
                      label: 'Активный концентратор',
                      value: receiver.isConnected
                          ? (receiver.connectedHub?.platformName ??
                              'BLE Alarm Hub')
                          : '—',
                    ),
                    Divider(height: 1, color: c.border),
                    _InfoRow(
                      label: 'MAC-адрес',
                      value: receiver.isConnected
                          ? (receiver.connectedHub?.remoteId.toString() ?? '—')
                          : '—',
                      mono: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FoundDeviceTile extends StatelessWidget {
  final ScanResult result;
  final ReceiverProvider receiver;
  final SettingsProvider settings;

  const _FoundDeviceTile({
    required this.result,
    required this.receiver,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final c    = appColors(context);
    final name = receiver.scanResultName(result);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.page,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub, color: _kAccBlue, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : 'BLE Hub',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.text1)),
                Text(result.device.remoteId.toString(),
                    style: TextStyle(
                        fontSize: 9,
                        color: c.text2,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => receiver.connectAsPrimaryDevice(
                result, settings.setPrimaryDevice),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccGreen.withOpacity(0.15),
                border: Border.all(color: _kAccGreen.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Выбрать',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kAccGreen)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BleActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BleActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: c.text2)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? c.text1,
                  fontFamily: mono ? 'monospace' : null,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Звук → Настройки звука
// ════════════════════════════════════════════════════════════════════════════

class SoundSettingsPage extends StatelessWidget {
  const SoundSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: _settingsAppBar(context, 'ЗВУК'),
      body: Consumer<ReceiverProvider>(
        builder: (ctx, receiver, _) {
          return ListView(
            children: [
              _SectionHeader('ОПОВЕЩЕНИЯ'),
              Container(
                color: c.surface,
                child: Column(
                  children: [
                    _SwitchRow(
                      icon: Icons.campaign_outlined,
                      title: 'Звук тревоги',
                      subtitle: 'Сирена при событии тревоги (код 0x55)',
                      value: receiver.soundEnabled,
                      onChanged: (on) async {
                        // Выключение — только по пин-коду
                        if (!on &&
                            !await showPinCheckDialog(ctx,
                                title: 'Выключить звук')) return;
                        receiver.setSoundEnabled(on);
                      },
                    ),
                  ],
                ),
              ),

              _SectionHeader('ИНФОРМАЦИЯ'),
              Container(
                color: c.surface,
                child: Column(
                  children: [
                    const _InfoRow(label: 'Тревога (0x55)',    value: 'alarm-siren.mp3'),
                    Builder(builder: (ctx2) => Divider(height: 1, color: appColors(ctx2).border)),
                    const _InfoRow(label: 'Разряд / вскрытие', value: 'seat-belt-unfastened.mp3'),
                    Builder(builder: (ctx2) => Divider(height: 1, color: appColors(ctx2).border)),
                    const _InfoRow(label: 'Аудио-поток',       value: 'Alarm (Android)'),
                    Builder(builder: (ctx2) => Divider(height: 1, color: appColors(ctx2).border)),
                    const _InfoRow(label: 'Тихий режим',       value: 'Игнорируется'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kAccBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _kAccBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.text1)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: c.text2)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _kAccBlue,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Выбор темы — три карточки: Тёмная / Светлая / Системная
// ════════════════════════════════════════════════════════════════════════════

class _ThemePicker extends StatelessWidget {
  final SettingsProvider settings;
  const _ThemePicker({required this.settings});

  static const _options = [
    (ThemeMode.dark,   Icons.dark_mode_outlined,    'Тёмная'),
    (ThemeMode.light,  Icons.light_mode_outlined,   'Светлая'),
    (ThemeMode.system, Icons.brightness_auto,        'Системная'),
  ];

  @override
  Widget build(BuildContext context) {
    final c       = appColors(context);
    final current = settings.themeMode;

    return Row(
      children: _options.map((opt) {
        final (mode, icon, label) = opt;
        final active = current == mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => settings.setThemeMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: active
                      ? _kAccBlue.withOpacity(0.15)
                      : c.page,
                  border: Border.all(
                    color: active ? _kAccBlue : c.border,
                    width: active ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 22,
                        color: active ? _kAccBlue : c.text2),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: active ? _kAccBlue : c.text2)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Уведомления → Связь с сервером по API
// Галочка включает блок; когда она снята, поля адреса, логина и пароля
// серые и недоступны для редактирования. Значения сохраняются в БД по мере ввода.
// ════════════════════════════════════════════════════════════════════════════

class _ServerApiBlock extends StatefulWidget {
  final SettingsProvider settings;
  const _ServerApiBlock({required this.settings});

  @override
  State<_ServerApiBlock> createState() => _ServerApiBlockState();
}

class _ServerApiBlockState extends State<_ServerApiBlock> {
  late final TextEditingController _url;
  late final TextEditingController _login;
  late final TextEditingController _password;
  bool _showPassword = false;
  bool _testing = false;
  String? _testResult; // null — проверки не было; '' — успешно; иначе ошибка

  Future<void> _setEnabled(bool v) async {
    await widget.settings.setApiEnabled(v);
    if (v) ApiSyncService().syncNow();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final err = await ApiSyncService().testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = err ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.settings.apiUrl);
    _login = TextEditingController(text: widget.settings.apiLogin);
    _password = TextEditingController(text: widget.settings.apiPassword);
  }

  @override
  void dispose() {
    _url.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final s = widget.settings;
    final enabled = s.apiEnabled;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _setEnabled(!enabled),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kAccBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_outlined,
                        size: 18, color: _kAccBlue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Связь с сервером по API',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: c.text1)),
                        const SizedBox(height: 2),
                        Text(enabled ? 'Включена' : 'Выключена',
                            style: TextStyle(fontSize: 11, color: c.text2)),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: enabled,
                    activeColor: _kAccBlue,
                    onChanged: (v) => _setEnabled(v ?? false),
                  ),
                ],
              ),
            ),
          ),
          Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(66, 0, 16, 14),
              child: Column(
                children: [
                  _field(
                    controller: _url,
                    label: 'Адрес сервера API',
                    hint: 'https://example.com/api',
                    enabled: enabled,
                    keyboard: TextInputType.url,
                    onChanged: s.setApiUrl,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _login,
                    label: 'Логин',
                    enabled: enabled,
                    onChanged: s.setApiLogin,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _password,
                    label: 'Пароль',
                    enabled: enabled,
                    obscure: !_showPassword,
                    onChanged: s.setApiPassword,
                    suffix: IconButton(
                      icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18),
                      onPressed: enabled
                          ? () => setState(() => _showPassword = !_showPassword)
                          : null,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 12),
                    _SyncStatus(testing: _testing, testResult: _testResult),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: _BleActionBtn(
                          label: _testing ? 'Проверка...' : 'Проверить связь',
                          icon: Icons.wifi_tethering,
                          color: _kAccBlue,
                          onTap: _testing ? () {} : _test,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BleActionBtn(
                          label: 'Отправить сейчас',
                          icon: Icons.cloud_upload_outlined,
                          color: _kAccGreen,
                          onTap: ApiSyncService().syncNow,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required ValueChanged<String> onChanged,
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    final c = appColors(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: !obscure,
      onChanged: onChanged,
      style: TextStyle(fontSize: 13, color: c.text1),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        suffixIcon: suffix,
      ),
    );
  }
}

// Строка состояния отправки журнала на сервер
class _SyncStatus extends StatelessWidget {
  final bool testing;
  final String? testResult;
  const _SyncStatus({required this.testing, required this.testResult});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final sync = context.watch<ApiSyncService>();

    final (IconData icon, Color color, String text) = switch (true) {
      _ when testing => (Icons.sync, c.text2, 'Проверка связи...'),
      _ when testResult != null && testResult!.isNotEmpty =>
        (Icons.error_outline, _kAccRed, testResult!),
      _ when testResult == '' => (Icons.check_circle_outline, _kAccGreen, 'Связь с сервером есть, вход выполнен'),
      _ when sync.lastError != null => (Icons.cloud_off, _kAccRed, sync.lastError!),
      _ when sync.isOnline => (Icons.cloud_done_outlined, _kAccGreen, 'Связь с сервером есть'),
      _ => (Icons.cloud_queue, c.text2, 'Ожидание отправки'),
    };

    final last = sync.lastSuccessAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ]),
        const SizedBox(height: 4),
        Text(
          'Не отправлено событий: ${sync.pendingCount}'
          '${last != null ? '  •  последняя отправка: ${DateFormat('dd.MM.yyyy HH:mm:ss').format(last)}' : ''}',
          style: TextStyle(fontSize: 11, color: c.text2),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Уведомления → Всплывать при тревоге (разрешение «Поверх других приложений»)
// ════════════════════════════════════════════════════════════════════════════

class _AlarmPopupRow extends StatefulWidget {
  const _AlarmPopupRow();

  @override
  State<_AlarmPopupRow> createState() => _AlarmPopupRowState();
}

class _AlarmPopupRowState extends State<_AlarmPopupRow>
    with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Вернулись из системных настроек — перепроверяем разрешение
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final g = await AppForeground.canDrawOverlays();
    if (mounted) setState(() => _granted = g);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted ?? false;
    return Column(children: [
      _SettingsRow(
        icon: Icons.open_in_full,
        title: 'Всплывать при тревоге',
        subtitle: _granted == null
            ? 'Проверка...'
            : granted
                ? 'Разрешение «Поверх других приложений» выдано'
                : 'Выключено — нажмите и разрешите «Поверх других приложений»',
        onTap: AppForeground.requestOverlayPermission,
      ),
      // Прошивки Xiaomi/Redmi/POCO, Huawei/Honor блокируют запуск из фона
      // отдельным собственным разрешением
      _SettingsRow(
        icon: Icons.phonelink_setup,
        title: 'Всплывающие окна в фоне (Xiaomi, Huawei)',
        subtitle: 'Разрешения → «Отображать всплывающие окна, когда приложение '
            'работает в фоне». Также: Уведомления → «Тревога» включены',
        onTap: AppForeground.openAppSettings,
      ),
    ]);
  }
}
