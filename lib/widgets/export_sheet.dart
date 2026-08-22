import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receiver_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

/// Нижний лист для выбора формата и экспорта журнала событий.
class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExportSheet(),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  ExportFormat _format = ExportFormat.pdf;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab bar
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Экспорт журнала событий',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.text1),
            ),
            const SizedBox(height: 4),
            Text(
              'Выберите формат файла',
              style: TextStyle(fontSize: 12, color: c.text2),
            ),
            const SizedBox(height: 16),

            // Format selector
            Row(
              children: [
                _FormatCard(
                  format: ExportFormat.pdf,
                  selected: _format == ExportFormat.pdf,
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  desc: 'Таблица, А4',
                  onTap: () => setState(() => _format = ExportFormat.pdf),
                ),
                const SizedBox(width: 10),
                _FormatCard(
                  format: ExportFormat.csv,
                  selected: _format == ExportFormat.csv,
                  icon: Icons.table_chart_outlined,
                  label: 'CSV',
                  desc: 'Excel / Sheets',
                  onTap: () => setState(() => _format = ExportFormat.csv),
                ),
                const SizedBox(width: 10),
                _FormatCard(
                  format: ExportFormat.txt,
                  selected: _format == ExportFormat.txt,
                  icon: Icons.text_snippet_outlined,
                  label: 'TXT',
                  desc: 'Текстовый',
                  onTap: () => setState(() => _format = ExportFormat.txt),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Share button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _share,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.share_outlined, size: 20),
                label: Text(_loading ? 'Формирую файл…' : 'Поделиться'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _loading = true);
    try {
      final rx = context.read<ReceiverProvider>();
      final events = rx.events; // список всех EventModel
      await ExportService().exportAndShare(events, format: _format);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка экспорта: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Format card ──────────────────────────────────────────────────────────────

class _FormatCard extends StatelessWidget {
  final ExportFormat format;
  final bool selected;
  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  const _FormatCard({
    required this.format,
    required this.selected,
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? kAccBlue.withOpacity(0.12)
                : c.tileBgDisarmed,
            border: Border.all(
              color: selected ? kAccBlue : c.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26, color: selected ? kAccBlue : c.text2),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? kAccBlue : c.text1)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(fontSize: 10, color: c.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
