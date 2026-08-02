import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/receiver_provider.dart';

const _kPage    = Color(0xFF0D1117);
const _kSurface = Color(0xFF161B22);
const _kBorder  = Color(0xFF2D3748);
const _kText1   = Color(0xFFD0DDD8);
const _kText2   = Color(0xFF6A8090);
const _kAccBlue = Color(0xFF4FC3F7);
const _kAccGreen = Color(0xFF34A853);
const _kAccRed = Color(0xFFEA4335);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPage,
      appBar: AppBar(
        backgroundColor: _kSurface,
        foregroundColor: _kText1,
        title: const Text(
          'НАСТРОЙКИ',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kBorder),
        ),
      ),
      body: Consumer2<SettingsProvider, ReceiverProvider>(
        builder: (context, settings, receiver, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              _SectionHeader('ОТОБРАЖЕНИЕ'),
              const SizedBox(height: 12),
              _FontScaleTile(settings: settings),
              const SizedBox(height: 24),
              _SectionHeader('ОСНОВНОЕ BLE-УСТРОЙСТВО'),
              const SizedBox(height: 12),
              _PrimaryDeviceSection(settings: settings, receiver: receiver),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: _kText2),
    );
  }
}

class _FontScaleTile extends StatelessWidget {
  final SettingsProvider settings;
  const _FontScaleTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    final scale = settings.fontScale;
    final pct   = (scale * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Размер шрифта',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kText1)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccBlue.withOpacity(0.15),
                  border: Border.all(color: _kAccBlue.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAccBlue,
                      fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Масштаб текста на основном экране',
            style: const TextStyle(fontSize: 11, color: _kText2),
          ),
          const SizedBox(height: 12),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kAccBlue,
              inactiveTrackColor: _kBorder,
              thumbColor: _kAccBlue,
              overlayColor: _kAccBlue.withOpacity(0.15),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: scale,
              min: 0.6,
              max: 2.0,
              divisions: 14,
              onChanged: settings.setFontScale,
            ),
          ),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _scaleBtn('−', () => settings.setFontScale(scale - 0.1)),
              Row(children: [
                _presetBtn('60%',  0.6,  scale, settings),
                const SizedBox(width: 6),
                _presetBtn('100%', 1.0,  scale, settings),
                const SizedBox(width: 6),
                _presetBtn('150%', 1.5,  scale, settings),
                const SizedBox(width: 6),
                _presetBtn('200%', 2.0,  scale, settings),
              ]),
              _scaleBtn('+', () => settings.setFontScale(scale + 0.1)),
            ],
          ),

          const SizedBox(height: 16),

          // Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPage,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _kBorder),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Зона 1  •  L50RA LoRa',
                      style: const TextStyle(
                          fontSize: 9, color: _kText2, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  Text('ТРЕВОГА',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA4335))),
                  Text('ID: 0001  •  Контроль',
                      style: const TextStyle(fontSize: 9, color: _kText2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scaleBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: _kBorder.withOpacity(0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 18, color: _kText1, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _presetBtn(
      String label, double value, double current, SettingsProvider s) {
    final active = (current - value).abs() < 0.05;
    return GestureDetector(
      onTap: () => s.setFontScale(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _kAccBlue.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
              color: active ? _kAccBlue : _kBorder),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? _kAccBlue : _kText2,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}

// ── Основное BLE-устройство ────────────────────────────────────────────────
//
// Вместо заранее прошитых в приложении UUID сервиса/характеристик, поиск
// концентратора теперь идёт по списку известных имён
// (ReceiverProvider.TARGET_DEVICE_NAMES). Пользователь ищет устройство здесь,
// выбирает нужное — оно запоминается как основное и постоянное, и при
// следующих запусках приложение подключается к нему автоматически.
class _PrimaryDeviceSection extends StatelessWidget {
  final SettingsProvider settings;
  final ReceiverProvider receiver;

  const _PrimaryDeviceSection({required this.settings, required this.receiver});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _currentDeviceRow(context),
          const SizedBox(height: 12),
          if (receiver.isPairingScan) ...[
            _scanningRow(),
            const SizedBox(height: 12),
          ],
          if (receiver.pairingResults.isNotEmpty) ...[
            ...receiver.pairingResults.map((r) => _foundDeviceTile(context, r)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: receiver.isPairingScan ? 'Остановить поиск' : 'Найти устройство',
                  icon: receiver.isPairingScan
                      ? Icons.stop_circle_outlined
                      : Icons.bluetooth_searching,
                  color: receiver.isPairingScan ? _kAccRed : _kAccBlue,
                  onTap: () => receiver.isPairingScan
                      ? receiver.stopPairingScan()
                      : receiver.startPairingScan(),
                ),
              ),
              if (settings.hasPrimaryDevice) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    label: 'Забыть',
                    icon: Icons.delete_outline,
                    color: _kText2,
                    onTap: settings.clearPrimaryDevice,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _currentDeviceRow(BuildContext context) {
    final has = settings.hasPrimaryDevice;
    return Row(
      children: [
        Icon(
          has ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          color: has ? _kAccGreen : _kText2,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                has ? (settings.primaryDeviceName ?? '') : 'Устройство не выбрано',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: has ? _kText1 : _kText2),
              ),
              if (has)
                Text(settings.primaryDeviceId ?? '',
                    style: const TextStyle(
                        fontSize: 10, color: _kText2, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scanningRow() {
    return Row(children: [
      const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _kAccBlue)),
      const SizedBox(width: 10),
      const Text('Поиск устройств из списка известных имён...',
          style: TextStyle(fontSize: 12, color: _kText2)),
    ]);
  }

  Widget _foundDeviceTile(BuildContext context, ScanResult result) {
    final name = receiver.scanResultName(result);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kPage,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub, color: _kAccBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : 'BLE Hub',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _kText1)),
                Text(result.device.remoteId.toString(),
                    style: const TextStyle(
                        fontSize: 9, color: _kText2, fontFamily: 'monospace')),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => receiver.connectAsPrimaryDevice(
              result,
              settings.setPrimaryDevice,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccGreen.withOpacity(0.15),
                border: Border.all(color: _kAccGreen.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Выбрать',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _kAccGreen)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
