import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/detector_model.dart';
import '../providers/receiver_provider.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
// Настройки → Программирование извещателей
//
// Квадратные блоки запрограммированных извещателей + последний блок «+».
// «+» включает режим программирования: приложение ждёт пакет с кодом 0x54
// (байт 3) и записывает новый извещатель в базу, после чего открывается
// диалог ввода зоны и места. Нажатие на извещатель — редактирование зоны и
// места или удаление.
// ════════════════════════════════════════════════════════════════════════════

class ProgrammingScreen extends StatefulWidget {
  const ProgrammingScreen({super.key});

  @override
  State<ProgrammingScreen> createState() => _ProgrammingScreenState();
}

class _ProgrammingScreenState extends State<ProgrammingScreen> {
  late final ReceiverProvider _prov;

  @override
  void initState() {
    super.initState();
    _prov = context.read<ReceiverProvider>();
    _prov.addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _prov.removeListener(_onProviderChanged);
    if (_prov.isProgramming) _prov.stopProgramming();
    super.dispose();
  }

  // Новый извещатель запрограммирован — сразу предлагаем ввести зону и место
  void _onProviderChanged() {
    final id = _prov.takeLastProgrammedId();
    if (id == null || !mounted) return;
    final det = _prov.detectors.where((d) => d.id == id).firstOrNull;
    if (det == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showEditDialog(det, isNew: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.text1,
        titleSpacing: 0,
        title: const Text('ПРОГРАММИРОВАНИЕ ИЗВЕЩАТЕЛЕЙ',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.border),
        ),
      ),
      body: Consumer<ReceiverProvider>(
        builder: (ctx, prov, _) {
          final detectors = prov.detectors;
          return Column(
            children: [
              if (prov.isProgramming) _ProgrammingBanner(prov: prov),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: detectors.length + 1,
                  itemBuilder: (_, i) {
                    if (i == detectors.length) {
                      return _AddTile(
                        empty: detectors.isEmpty,
                        active: prov.isProgramming,
                        onTap: prov.isProgramming
                            ? prov.stopProgramming
                            : prov.startProgramming,
                      );
                    }
                    final d = detectors[i];
                    return _DetectorSquare(
                      detector: d,
                      number: i + 1,
                      onTap: () => _showEditDialog(d),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Диалог зоны/места + удаление ──────────────────────────────────────────

  Future<void> _showEditDialog(DetectorModel d, {bool isNew = false}) async {
    final c = appColors(context);
    final zoneCtrl = TextEditingController(text: d.zoneName);
    final placeCtrl = TextEditingController(text: d.place);

    final result = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(isNew
            ? 'Новый извещатель ${d.name} [${d.id}]'
            : '${d.name} [${d.id}]'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SuggestField(
                controller: zoneCtrl,
                label: 'Зона (объект)',
                hint: 'Например: склад, периметр, офис',
                suggestions: _prov.knownZoneNames,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              SuggestField(
                controller: placeCtrl,
                label: 'Место',
                hint: 'Например: дверь, окно, ворота',
                suggestions: _prov.knownPlaces,
              ),
            ],
          ),
        ),
        actions: [
          if (!isNew)
            TextButton(
              onPressed: () => Navigator.pop(dCtx, 'delete'),
              child: const Text('Удалить', style: TextStyle(color: kAccRed)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, 'save'),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'save') {
      await _prov.updateDetectorZonePlace(d.id, zoneCtrl.text, placeCtrl.text);
    } else if (result == 'delete') {
      await _confirmDelete(d);
    }
  }

  Future<void> _confirmDelete(DetectorModel d) async {
    final c = appColors(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Удалить извещатель?'),
        content: Text(
            '${d.name} [${d.id}] будет удалён из базы. Приложение перестанет '
            'реагировать на его сигналы, пока он не будет запрограммирован заново.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Удалить', style: TextStyle(color: kAccRed))),
        ],
      ),
    );
    if (ok == true) await _prov.deleteDetector(d.id);
  }
}

// ── Баннер режима программирования ──────────────────────────────────────────

class _ProgrammingBanner extends StatelessWidget {
  final ReceiverProvider prov;
  const _ProgrammingBanner({required this.prov});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kAccAmber.withOpacity(0.15),
        border: Border(bottom: BorderSide(color: kAccAmber.withOpacity(0.6))),
      ),
      child: Row(children: [
        const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: kAccAmber)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Вставьте элемент питания в извещатель',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text1)),
              const SizedBox(height: 2),
              Text(
                prov.programmingMessage ??
                    (prov.isConnected
                        ? 'Ожидание сигнала инициализации от извещателя...'
                        : 'Нет связи с BT-устройством — сигнал не будет получен'),
                style: TextStyle(
                    fontSize: 11,
                    color: prov.programmingMessage != null || !prov.isConnected
                        ? kAccRed
                        : c.text2),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: prov.stopProgramming,
          child: const Text('Отмена'),
        ),
      ]),
    );
  }
}

// ── Блок «+» ────────────────────────────────────────────────────────────────

class _AddTile extends StatelessWidget {
  final bool empty;   // в базе нет извещателей — блок красный
  final bool active;  // идёт программирование
  final VoidCallback onTap;

  const _AddTile({required this.empty, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final color = active ? kAccAmber : (empty ? kAccRed : kAccBlue);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: empty && !active ? kAccRed.withOpacity(0.25) : c.surface,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? Icons.hourglass_top : Icons.add, size: 48, color: color),
            const SizedBox(height: 6),
            Text(active ? 'Ожидание...' : 'Добавить',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Блок извещателя ─────────────────────────────────────────────────────────

class _DetectorSquare extends StatelessWidget {
  final DetectorModel detector;
  final int number;
  final VoidCallback onTap;

  const _DetectorSquare(
      {required this.detector, required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final d = detector;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.zoneName.isEmpty ? 'Зона не задана' : d.zoneName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: d.zoneName.isEmpty ? c.text2 : c.text1)),
            Text(d.place.isEmpty ? 'Место не задано' : d.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.text2)),
            Expanded(
              child: Center(
                child: Text('$number',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: c.text2.withOpacity(0.6))),
              ),
            ),
            Text('${d.name} LoRa',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: kAccBlue)),
            Text('ID ${d.id}',
                style: TextStyle(
                    fontSize: 10, color: c.text2, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

// ── Поле ввода с подсказками из уже введённых значений ──────────────────────

class SuggestField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> suggestions;
  final bool autofocus;

  const SuggestField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.suggestions,
    this.autofocus = false,
  });

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return widget.suggestions.where((s) {
          final l = s.toLowerCase();
          return l.startsWith(q) && l != q;
        });
      },
      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextField(
        controller: ctrl,
        focusNode: focus,
        autofocus: widget.autofocus,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          counterText: '',
        ),
        onSubmitted: (_) => onSubmit(),
      ),
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: c.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 320),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: options
                  .map((o) => ListTile(
                        dense: true,
                        title: Text(o, style: TextStyle(color: c.text1)),
                        onTap: () => onSelected(o),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
