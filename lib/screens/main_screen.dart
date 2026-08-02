import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/detector_model.dart';
import '../models/event_model.dart';
import '../providers/receiver_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../widgets/detector_tile.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _kPage     = Color(0xFF0D1117);
const _kSurface  = Color(0xFF161B22);
const _kBorder   = Color(0xFF2D3748);
const _kText1    = Color(0xFFD0DDD8);
const _kText2    = Color(0xFF6A8090);
const _kAccBlue  = Color(0xFF4FC3F7);
const _kAccGreen = Color(0xFF34A853);
const _kAccRed   = Color(0xFFEA4335);
const _kAccAmber = Color(0xFFFBBC04);
// ─────────────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String? _selectedId; // selected detector id for right panel

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _autoConnectSavedDevice();
  }

  // При старте приложения пробуем автоматически подключиться к основному
  // BLE-устройству, ранее выбранному пользователем на экране настроек
  // (см. SettingsProvider.primaryDeviceId / ReceiverProvider.autoConnectToSaved).
  Future<void> _autoConnectSavedDevice() async {
    final receiver = context.read<ReceiverProvider>();
    final settings = context.read<SettingsProvider>();

    await receiver.requestPermissions();
    await settings.load();
    await receiver.autoConnectToSaved(
        settings.primaryDeviceId, settings.primaryDeviceName);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Root ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReceiverProvider, SettingsProvider>(
      builder: (ctx, prov, settings, _) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
            textScaler: TextScaler.linear(settings.fontScale)),
        child: Scaffold(
          backgroundColor: _kPage,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  provider: prov,
                  onConnect: () => _showConnectionDialog(ctx, prov),
                  onSettings: () => Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              Expanded(
                child: LayoutBuilder(builder: (_, c) {
                  final wide = c.maxWidth > 560;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildGrid(prov)),
                      if (wide) _RightPanel(
                        provider: prov,
                        selectedId: _selectedId,
                        onClose: () => setState(() => _selectedId = null),
                      ),
                    ]);
                }),
              ),
              _BottomBar(provider: prov),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Detector grid ─────────────────────────────────────────────────────────

  Widget _buildGrid(ReceiverProvider prov) {
    if (prov.detectors.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sensors_off, size: 48, color: _kText2.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('Нет подключённых извещателей',
              style: TextStyle(color: _kText2, fontSize: 13)),
          const SizedBox(height: 12),
          if (!prov.isConnected)
            _OutlineBtn(
              label: 'Подключиться',
              icon: Icons.bluetooth_searching,
              onTap: prov.startScanning,
            ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(builder: (_, c) {
        final n    = prov.detectors.length;
        final cols = _cols(n);
        final rows = (n / cols).ceil();
        final gap  = 5.0;
        final tw   = (c.maxWidth  - (cols - 1) * gap) / cols;
        final th   = (c.maxHeight - (rows - 1) * gap) / rows;
        final ar   = tw / th.clamp(1, double.infinity);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: ar,
          ),
          itemCount: n,
          itemBuilder: (_, i) {
            final d = prov.detectors[i];
            return DetectorTile(
              detector:         d,
              number:           i + 1,
              alarmBorderActive: prov.alarmBorderActive[d.id] ?? false,
              alarmStartTime:   prov.alarmStartTimes[d.id],
              isSelected:       _selectedId == d.id,
              onTap: () {
                final hasAlarm = (prov.alarmBorderActive[d.id] ?? false) ||
                    d.status == DetectorStatus.alarm ||
                    d.status == DetectorStatus.tamper;
                if (hasAlarm) {
                  prov.disarmDetectorAlarm(d.id);
                } else {
                  setState(() =>
                      _selectedId = _selectedId == d.id ? null : d.id);
                }
              },
              onResetAlarm: () => prov.disarmDetectorAlarm(d.id),
            );
          },
        );
      }),
    );
  }

  int _cols(int n) {
    if (n <= 4)  return 2;
    if (n <= 6)  return 3;
    if (n <= 12) return 4;
    return 5;
  }

  // ── Connection dialog ─────────────────────────────────────────────────────

  void _showConnectionDialog(BuildContext ctx, ReceiverProvider prov) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('УПРАВЛЕНИЕ ПОДКЛЮЧЕНИЕМ',
              style: TextStyle(fontSize: 11, letterSpacing: 2,
                  fontWeight: FontWeight.w700, color: _kText2)),
          const SizedBox(height: 16),
          if (prov.isConnected) ...[
            _statusRow(Icons.bluetooth_connected, _kAccGreen,
                prov.connectedHub?.platformName ?? 'BLE Alarm Hub',
                prov.connectedHub?.remoteId.toString() ?? ''),
            const SizedBox(height: 16),
            _DarkBtn(
              label: 'Отключиться',
              color: _kAccRed,
              onTap: () {
                prov.disconnectFromHub();
                Navigator.pop(ctx);
              },
            ),
          ] else if (prov.isScanning) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      color: _kAccBlue)),
              const SizedBox(width: 12),
              Text('Поиск концентраторов...',
                  style: TextStyle(color: _kText2)),
            ]),
          ] else ...[
            _DarkBtn(
              label: 'Начать поиск',
              color: _kAccBlue,
              icon: Icons.bluetooth_searching,
              onTap: prov.startScanning,
            ),
            if (prov.discoveredHubs.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...prov.discoveredHubs.map((hub) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hub, color: _kAccBlue, size: 18),
                title: Text(
                  hub.platformName.isNotEmpty ? hub.platformName : 'BLE Hub',
                  style: const TextStyle(color: _kText1, fontSize: 13),
                ),
                subtitle: Text(hub.remoteId.toString(),
                    style: const TextStyle(color: _kText2, fontSize: 10)),
                trailing: _DarkBtn(
                  label: 'Подключить',
                  color: _kAccGreen,
                  onTap: () {
                    prov.connectToHub(hub);
                    Navigator.pop(ctx);
                  },
                ),
              )),
            ],
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String title, String sub) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: _kText1, fontSize: 13)),
        Text(sub, style: TextStyle(color: _kText2, fontSize: 10)),
      ]),
    ]);
  }
}

// ── Clock (isolated so only this widget rebuilds every second) ────────────────

class _ClockText extends StatefulWidget {
  final TextStyle style;
  final String format;
  const _ClockText({required this.style, this.format = 'HH:mm:ss'});

  @override
  State<_ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends State<_ClockText> {
  late DateTime _now;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      Text(DateFormat(widget.format).format(_now), style: widget.style);
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final ReceiverProvider provider;
  final VoidCallback onConnect;
  final VoidCallback onSettings;

  const _TopBar({required this.provider, required this.onConnect, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // Logo
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('ZHURIN',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: _kAccBlue, letterSpacing: 2.5, height: 1)),
            Text('ELECTRONICS',
                style: TextStyle(
                    fontSize: 7, color: _kText2,
                    letterSpacing: 1.8, height: 1)),
          ],
        ),
        Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            width: 1, height: 30, color: _kBorder),

        // Status chips
        _chip('ТРЕВОГА', provider.alarmDetectors,    _kAccRed),
        const SizedBox(width: 5),
        _chip('НОРМА',   _normalCount,                _kAccGreen),
        const SizedBox(width: 5),
        _chip('ОХРАНА',  _armedCount,                 _kAccBlue.withOpacity(0.9)),
        const SizedBox(width: 5),
        _chip('НЕТ СВ.', provider.offlineDetectors,  _kText2),

        const Spacer(),

        // Clock — isolated widget, rebuilds only itself
        const _ClockText(
          format: 'HH:mm:ss',
          style: TextStyle(
              fontFamily: 'monospace', fontSize: 22,
              fontWeight: FontWeight.w700, color: _kAccBlue, letterSpacing: 2.5),
        ),

        const SizedBox(width: 16),

        // Sound toggle
        _iconBtn(
          provider.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          provider.soundEnabled ? _kAccBlue : _kText2,
          provider.toggleSound,
        ),

        // Arm / disarm all
        GestureDetector(
          onTap: () {
            final allArmed = provider.detectors.every((d) => d.isArmed);
            if (allArmed) provider.disarmAll(); else provider.armAll();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _armedAll
                  ? const Color(0xFF1A4A1A)
                  : const Color(0xFF4A1A1A),
              border: Border.all(
                  color: _armedAll
                      ? const Color(0xFF2A7A2A)
                      : const Color(0xFF7A2A2A)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _armedAll ? '🔒  ОХРАНА' : '🔓  СНЯТО',
              style: const TextStyle(fontSize: 10, letterSpacing: 0.5,
                  color: _kText1),
            ),
          ),
        ),

        // BLE button
        _iconBtn(
          provider.isConnected
              ? Icons.bluetooth_connected
              : Icons.bluetooth_searching,
          provider.isConnected ? _kAccBlue : _kText2,
          onConnect,
        ),

        // Settings button
        _iconBtn(Icons.settings_outlined, _kText2, onSettings),
      ]),
    );
  }

  int get _normalCount => provider.detectors
      .where((d) => d.status == DetectorStatus.normal && d.isArmed)
      .length;
  int get _armedCount  => provider.detectors.where((d) => d.isArmed).length;
  bool get _armedAll   => provider.detectors.isNotEmpty &&
      provider.detectors.every((d) => d.isArmed);

  Widget _chip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 8, color: color, letterSpacing: 0.4)),
        const SizedBox(width: 4),
        Text('$count',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }
}

// ── Right Panel ───────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final ReceiverProvider provider;
  final String? selectedId;
  final VoidCallback onClose;

  const _RightPanel(
      {required this.provider,
      required this.selectedId,
      required this.onClose});

  DetectorModel? get _selected => selectedId == null
      ? null
      : provider.detectors.cast<DetectorModel?>().firstWhere(
            (d) => d!.id == selectedId,
            orElse: () => null,
          );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(left: BorderSide(color: _kBorder)),
      ),
      child: Column(children: [
        // Header
        _panelHeader(),
        // Detector detail
        if (_selected != null) ...[
          _DetectorDetail(
              detector: _selected!,
              alarmBorderActive:
                  provider.alarmBorderActive[_selected!.id] ?? false,
              onArm:   () => provider.armDetector(_selected!.id),
              onDisarm:() => provider.disarmDetector(_selected!.id),
              onReset: () => provider.disarmDetectorAlarm(_selected!.id)),
          const Divider(height: 1, color: _kBorder),
        ],
        // Event log
        Expanded(child: _EventLog(
          events: _filteredEvents,
        )),
      ]),
    );
  }

  List<EventModel> get _filteredEvents {
    if (selectedId != null) {
      return provider.events
          .where((e) => e.detectorId == selectedId)
          .take(80)
          .toList();
    }
    return provider.events.take(150).toList();
  }

  Widget _panelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder))),
      child: Row(children: [
        const Text('ПАНЕЛЬ',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 1.8, color: _kText2)),
        const Spacer(),
        if (selectedId != null)
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded, size: 14, color: _kText2),
          ),
      ]),
    );
  }
}

// ── Detector Detail ───────────────────────────────────────────────────────────

class _DetectorDetail extends StatelessWidget {
  final DetectorModel detector;
  final bool alarmBorderActive;
  final VoidCallback onArm;
  final VoidCallback onDisarm;
  final VoidCallback onReset;

  const _DetectorDetail({
    required this.detector,
    required this.alarmBorderActive,
    required this.onArm,
    required this.onDisarm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final sc = detector.statusColor;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: sc.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: sc.withOpacity(0.5)),
            ),
            child: Icon(detector.icon, color: sc, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${detector.name}  [${detector.id}]',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _kText1),
                  overflow: TextOverflow.ellipsis),
              Text(detector.statusText,
                  style: TextStyle(fontSize: 10, color: sc)),
            ],
          )),
        ]),
        const SizedBox(height: 10),
        _row('Модель',  '${detector.name} LoRa'),
        _row('Зона',    'Зона ${detector.zone}'),
        _row('Событие', detector.lastEventText),
        _row('Связь',   _ago(detector.lastSeen)),
        _row('Тревог',  '${detector.alarmCount}'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _btn(
            detector.isArmed ? 'Снять' : 'На охрану',
            detector.isArmed ? const Color(0xFF6A2A00) : const Color(0xFF1A5A1A),
            detector.isArmed ? onDisarm : onArm,
          )),
          const SizedBox(width: 8),
          Expanded(child: _btn(
            'Сброс',
            alarmBorderActive ||
                    detector.status == DetectorStatus.alarm ||
                    detector.status == DetectorStatus.tamper
                ? const Color(0xFF5A1010)
                : const Color(0xFF1E1E1E),
            alarmBorderActive ||
                    detector.status == DetectorStatus.alarm ||
                    detector.status == DetectorStatus.tamper
                ? onReset
                : null,
          )),
        ]),
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
            width: 58,
            child: Text(label,
                style: const TextStyle(fontSize: 9, color: _kText2))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 9, color: _kText1),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _btn(String label, Color bg, VoidCallback? onTap) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? bg : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
              color: active ? bg : const Color(0xFF2A2A2A)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: active ? _kText1 : const Color(0xFF3A3A3A))),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60)  return 'только что';
    if (d.inMinutes < 60)  return '${d.inMinutes} мин';
    if (d.inHours   < 24)  return '${d.inHours} ч';
    return '${d.inDays} дн';
  }
}

// ── Event Log ─────────────────────────────────────────────────────────────────

class _EventLog extends StatelessWidget {
  final List<EventModel> events;
  const _EventLog({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Log header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder))),
        child: Row(children: [
          const Text('ЖУРНАЛ СОБЫТИЙ',
              style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  letterSpacing: 1.6, color: _kText2)),
          const Spacer(),
          Text('${events.length}',
              style: const TextStyle(fontSize: 9, color: _kText2)),
        ]),
      ),
      // Events list
      Expanded(
        child: events.isEmpty
            ? Center(
                child: Text('Нет событий',
                    style: TextStyle(
                        fontSize: 12, color: _kText2.withOpacity(0.5))))
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: events.length,
                itemBuilder: (_, i) => _EventRow(event: events[i]),
              ),
      ),
    ]);
  }
}

class _EventRow extends StatelessWidget {
  final EventModel event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFF1A2030), width: 0.5))),
      child: Row(children: [
        Container(
          width: 3, height: 28,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description,
                style: const TextStyle(fontSize: 10, color: _kText1),
                overflow: TextOverflow.ellipsis),
            Text(
              DateFormat('dd.MM  HH:mm:ss').format(event.timestamp),
              style: const TextStyle(fontSize: 8, color: _kText2),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(_short(event.type),
              style: TextStyle(
                  fontSize: 8, color: color, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  String _short(EventType t) {
    switch (t) {
      case EventType.alarm:         return 'ТРВ';
      case EventType.tamper:        return 'ВСК';
      case EventType.lowBattery:    return 'БАТ';
      case EventType.restored:      return 'НРМ';
      case EventType.connected:     return 'ПДК';
      case EventType.disconnected:  return 'ОТК';
      case EventType.armed:         return 'ОХР';
      case EventType.disarmed:      return 'СНЯ';
      case EventType.systemArmed:   return 'С-ОХ';
      case EventType.systemDisarmed:return 'С-СН';
      case EventType.zoneArmed:     return 'З-ОХ';
      case EventType.zoneDisarmed:  return 'З-СН';
    }
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final ReceiverProvider provider;
  const _BottomBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
          color: _kPage,
          border: Border(top: BorderSide(color: _kBorder))),
      child: Row(children: [
        _item(
          provider.isConnected
              ? Icons.bluetooth_connected
              : Icons.bluetooth_disabled,
          provider.isConnected
              ? (provider.connectedHub?.platformName ?? 'BLE')
              : 'Нет связи',
          provider.isConnected ? _kAccBlue : _kText2,
        ),
        _div(),
        _item(Icons.sensors_rounded,
            '${provider.totalDetectors} датч.', _kText2),
        _div(),
        _item(Icons.warning_amber_rounded,
            '${provider.alarmDetectors} тревог',
            provider.alarmDetectors > 0 ? _kAccRed : _kText2),
        _div(),
        _item(Icons.no_photography_outlined,
            '${provider.offlineDetectors} нет св.', _kText2),
        const Spacer(),
        const _ClockText(
          format: 'dd.MM.yyyy',
          style: TextStyle(fontSize: 9, color: _kText2),
        ),
      ]),
    );
  }

  Widget _item(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 9, color: color)),
    ]);
  }

  Widget _div() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 1, height: 12, color: _kBorder);
}

// ── Shared UI helpers ─────────────────────────────────────────────────────────

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _OutlineBtn(
      {required this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _kAccBlue.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _kAccBlue),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: const TextStyle(fontSize: 12, color: _kAccBlue)),
        ]),
      ),
    );
  }
}

class _DarkBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;
  const _DarkBtn(
      {required this.label, required this.color, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
