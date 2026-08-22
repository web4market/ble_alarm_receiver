import 'dart:io';
import 'package:flutter/material.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event_model.dart';

/// Форматы экспорта
enum ExportFormat { pdf, csv, txt }

class ExportService {
  static final ExportService _i = ExportService._();
  factory ExportService() => _i;
  ExportService._();

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Создать файл нужного формата и отправить через «Поделиться».
  Future<void> exportAndShare(
    List<EventModel> events, {
    required ExportFormat format,
    DateTime? from,
    DateTime? to,
  }) async {
    final filtered = _filter(events, from, to);
    final file = await switch (format) {
      ExportFormat.pdf => _buildPdf(filtered, from, to),
      ExportFormat.csv => _buildCsv(filtered),
      ExportFormat.txt => _buildTxt(filtered),
    };

    final ext = switch (format) {
      ExportFormat.pdf => 'pdf',
      ExportFormat.csv => 'csv',
      ExportFormat.txt => 'txt',
    };
    final subject = 'Журнал событий сигнализации ($ext)';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mime(format))],
        subject: subject,
        text: subject,
      ),
    );
  }

  // ── PDF ──────────────────────────────────────────────────────────────────────

  Future<File> _buildPdf(
      List<EventModel> events, DateTime? from, DateTime? to) async {
    // Кириллический шрифт (Noto Sans, кешируется Google Fonts API)
    pw.Font? regular;
    pw.Font? bold;
    try {
      regular = await PdfGoogleFonts.notoSansRegular();
      bold    = await PdfGoogleFonts.notoSansBold();
    } catch (e) {
      debugPrint('ExportService: font load failed ($e), using built-in');
    }

    pw.TextStyle ts(double size, {bool isBold = false, PdfColor? color}) {
      final f = isBold ? (bold ?? pw.Font.helveticaBold())
                       : (regular ?? pw.Font.helvetica());
      return pw.TextStyle(font: f, fontSize: size, color: color);
    }

    final df  = DateFormat('dd.MM.yyyy');
    final dtf = DateFormat('dd.MM.yyyy HH:mm:ss');
    final now = DateTime.now();

    final periodLabel = (from != null || to != null)
        ? '${from != null ? df.format(from) : '—'}  →  ${to != null ? df.format(to) : '—'}'
        : 'Все время';

    // ── Колонки таблицы ────────────────────────────────────────────────────────
    const cols = ['Дата / Время', 'Тип', 'Извещатель', 'Описание'];
    const flex = [2, 2, 2, 4];

    // ── Заголовок страницы ────────────────────────────────────────────────────
    pw.Widget header() => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ZHURIN ELECTRONICS',
                style: ts(14, isBold: true,
                    color: const PdfColor.fromInt(0xFF4FC3F7))),
            pw.Text('Стр. #', style: ts(9, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('ЖУРНАЛ СОБЫТИЙ СИГНАЛИЗАЦИИ',
            style: ts(18, isBold: true)),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          _kv('Период:', periodLabel, ts),
          pw.SizedBox(width: 24),
          _kv('Записей:', '${events.length}', ts),
          pw.SizedBox(width: 24),
          _kv('Сформирован:', dtf.format(now), ts),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 6),
        // Заголовок таблицы
        pw.Row(
          children: List.generate(cols.length, (i) => pw.Expanded(
            flex: flex[i],
            child: pw.Text(cols[i], style: ts(8, isBold: true)),
          )),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      ],
    );

    // ── Строка события ────────────────────────────────────────────────────────
    pw.Widget eventRow(EventModel e, int idx) {
      final bg = idx.isEven
          ? const PdfColor.fromInt(0xFFFAFAFA)
          : PdfColors.white;
      final typeColor = _pdfColor(e.type);
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: pw.Row(children: [
          pw.Expanded(flex: flex[0],
              child: pw.Text(dtf.format(e.timestamp.toLocal()),
                  style: ts(7.5))),
          pw.Expanded(flex: flex[1],
              child: pw.Text(_typeName(e.type),
                  style: ts(7.5, color: typeColor, isBold: true))),
          pw.Expanded(flex: flex[2],
              child: pw.Text(e.detectorName, style: ts(7.5))),
          pw.Expanded(flex: flex[3],
              child: pw.Text(e.description, style: ts(7.5))),
        ]),
      );
    }

    // ── Сборка документа ──────────────────────────────────────────────────────
    final doc = pw.Document(
      title: 'Журнал событий',
      author: 'Zhurin Electronics',
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      header: (_) => header(),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Zhurin Electronics — BLE Alarm System',
              style: ts(7, color: PdfColors.grey500)),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
              style: ts(7, color: PdfColors.grey500)),
        ],
      ),
      build: (ctx) => [
        for (int i = 0; i < events.length; i++) eventRow(events[i], i),
      ],
    ));

    return _saveTemp('events_${_stamp()}.pdf', await doc.save());
  }

  // ── CSV ──────────────────────────────────────────────────────────────────────

  Future<File> _buildCsv(List<EventModel> events) async {
    final dtf = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buf = StringBuffer();
    buf.writeln('Дата/Время,Тип,Извещатель,Описание');
    for (final e in events) {
      final fields = [
        dtf.format(e.timestamp.toLocal()),
        _typeName(e.type),
        e.detectorName,
        e.description.replaceAll('"', '""'),
      ];
      buf.writeln(fields.map((f) => '"$f"').join(','));
    }
    return _saveTextTemp('events_${_stamp()}.csv', buf.toString());
  }

  // ── TXT ──────────────────────────────────────────────────────────────────────

  Future<File> _buildTxt(List<EventModel> events) async {
    final dtf  = DateFormat('dd.MM.yyyy HH:mm:ss');
    final now  = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    final buf  = StringBuffer();
    buf.writeln('═══════════════════════════════════════════════════════');
    buf.writeln(' ZHURIN ELECTRONICS — ЖУРНАЛ СОБЫТИЙ СИГНАЛИЗАЦИИ');
    buf.writeln(' Сформирован: $now   Записей: ${events.length}');
    buf.writeln('═══════════════════════════════════════════════════════');
    buf.writeln();
    for (final e in events) {
      buf.writeln('${dtf.format(e.timestamp.toLocal())}  [${_typeName(e.type).padRight(12)}]'
          '  ${e.detectorName.padRight(10)}  ${e.description}');
    }
    buf.writeln();
    buf.writeln('═══════════════════════════════════════════════════════');
    return _saveTextTemp('events_${_stamp()}.txt', buf.toString());
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<EventModel> _filter(List<EventModel> all, DateTime? from, DateTime? to) {
    var list = List<EventModel>.from(all);
    if (from != null) list = list.where((e) => !e.timestamp.isBefore(from)).toList();
    if (to   != null) list = list.where((e) => !e.timestamp.isAfter(to)).toList();
    return list;
  }

  Future<File> _saveTemp(String name, List<int> bytes) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> _saveTextTemp(String name, String text) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(text);
    return file;
  }

  String _stamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  String _mime(ExportFormat f) => switch (f) {
        ExportFormat.pdf => 'application/pdf',
        ExportFormat.csv => 'text/csv',
        ExportFormat.txt => 'text/plain',
      };

  String _typeName(EventType t) => switch (t) {
        EventType.alarm          => 'Тревога',
        EventType.tamper         => 'Вскрытие',
        EventType.lowBattery     => 'Разряд',
        EventType.restored       => 'Норма',
        EventType.connected      => 'Подключение',
        EventType.disconnected   => 'Отключение',
        EventType.armed          => 'На охрану',
        EventType.disarmed       => 'Снят',
        EventType.systemArmed    => 'Сис. охрана',
        EventType.systemDisarmed => 'Сис. снят',
        EventType.zoneArmed      => 'Зона охрана',
        EventType.zoneDisarmed   => 'Зона снята',
      };

  PdfColor _pdfColor(EventType t) => switch (t) {
        EventType.alarm          => const PdfColor.fromInt(0xFFEA4335),
        EventType.tamper         => const PdfColor.fromInt(0xFF9C27B0),
        EventType.lowBattery     => const PdfColor.fromInt(0xFFFF9800),
        EventType.restored       => const PdfColor.fromInt(0xFF34A853),
        EventType.connected      => const PdfColor.fromInt(0xFF2196F3),
        EventType.disconnected   => PdfColors.grey600,
        EventType.armed          => const PdfColor.fromInt(0xFF34A853),
        EventType.disarmed       => const PdfColor.fromInt(0xFFFF9800),
        EventType.systemArmed    => const PdfColor.fromInt(0xFF34A853),
        EventType.systemDisarmed => const PdfColor.fromInt(0xFFFF9800),
        EventType.zoneArmed      => const PdfColor.fromInt(0xFF34A853),
        EventType.zoneDisarmed   => const PdfColor.fromInt(0xFFFF9800),
      };

  pw.Widget _kv(String k, String v,
      pw.TextStyle Function(double, {bool isBold, PdfColor? color}) ts) {
    return pw.Row(children: [
      pw.Text(k, style: ts(8, isBold: true, color: PdfColors.grey600)),
      pw.SizedBox(width: 4),
      pw.Text(v, style: ts(8)),
    ]);
  }
}
