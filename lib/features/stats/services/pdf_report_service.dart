import 'dart:io';

import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─── Palette PDF ──────────────────────────────────────────────────────────────

const _kAzure      = PdfColor.fromInt(0xFF007FFF);
const _kDarkBlue   = PdfColor.fromInt(0xFF0066CC);
const _kGreen      = PdfColor.fromInt(0xFF22C55E);
const _kRed        = PdfColor.fromInt(0xFFEF4444);
const _kOrange     = PdfColor.fromInt(0xFFFF8C00);
const _kPurple     = PdfColor.fromInt(0xFF8B5CF6);
const _kGray       = PdfColor.fromInt(0xFF6B7280);
const _kLightGray  = PdfColor.fromInt(0xFFF3F4F6);
const _kBorder     = PdfColor.fromInt(0xFFE5E7EB);
const _kText       = PdfColor.fromInt(0xFF1A1A2E);
const _kWhite      = PdfColors.white;

// ─── Service ──────────────────────────────────────────────────────────────────

class PdfReportService {
  PdfReportService._();

  static Future<void> generateAndOpen({
    required String sensorName,
    required String macAddress,
    required String sensorType,
    required DateTime date,
    required List<Map<String, dynamic>> readings,
  }) async {
    final doc = pw.Document(
      title: 'Rapport Journalier – $sensorName',
      author: 'SIRIUS IoT',
    );

    final dateLabel = DateFormat('dd/MM/yyyy').format(date);

    // ── Stats ────────────────────────────────────────────────────────────────
    final temps  = _values(readings, 'temperature');
    final hums   = _values(readings, 'humidity');
    final press  = _values(readings, 'presure');
    final hasHum  = sensorType == '1' || sensorType == '6';
    final hasPress = sensorType == '1';

    // ── Trier par heure ───────────────────────────────────────────────────────
    final sorted = List<Map<String, dynamic>>.from(readings)
      ..sort((a, b) => (a['InfoDate'] as int).compareTo(b['InfoDate'] as int));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (_) => _pageHeader(sensorName, macAddress, dateLabel, readings.length),
        footer: (ctx) => _pageFooter(ctx, dateLabel),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          _sectionTitle('Résumé de la journée', 0xFF007FFF),
          pw.SizedBox(height: 10),
          _statsRow(
            temps:  temps,
            hums:   hums,
            press:  press,
            hasHum:  hasHum,
            hasPress: hasPress,
          ),
          pw.SizedBox(height: 24),
          _sectionTitle('Relevés détaillés', 0xFF007FFF),
          pw.SizedBox(height: 10),
          _dataTable(sorted, hasHum: hasHum, hasPress: hasPress),
        ],
      ),
    );

    final dir  = await getTemporaryDirectory();
    final safe = sensorName.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File(
      '${dir.path}/rapport_${safe}_${date.year}-${_p(date.month)}-${_p(date.day)}.pdf',
    );
    await file.writeAsBytes(await doc.save());
    await OpenFile.open(file.path);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static String _p(int v) => v.toString().padLeft(2, '0');

  static List<double> _values(List<Map<String, dynamic>> rows, String key) =>
      rows.where((r) => r[key] != null).map((r) => (r[key] as num).toDouble()).toList();

  static double _min(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a < b ? a : b);
  static double _max(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);
  static double _avg(List<double> v) =>
      v.isEmpty ? 0 : v.fold(0.0, (a, b) => a + b) / v.length;

  // ─── En-tête de page ─────────────────────────────────────────────────────────

  static pw.Widget _pageHeader(
    String name,
    String mac,
    String dateLabel,
    int count,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_kDarkBlue, _kAzure],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SIRIUS IoT',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 10,
                      color: const PdfColor(1, 1, 1, 0.65),
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Rapport Journalier',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 20,
                      color: _kWhite,
                    ),
                  ),
                ],
              ),
              // Badge date
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(1, 1, 1, 0.15),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                ),
                child: pw.Text(
                  dateLabel,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 12,
                    color: _kWhite,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            height: 1,
            color: const PdfColor(1, 1, 1, 0.20),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _headerChip('Capteur', name),
              pw.SizedBox(width: 16),
              _headerChip('MAC', mac),
              pw.SizedBox(width: 16),
              _headerChip('Mesures', '$count relevés'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _headerChip(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 7,
            color: const PdfColor(1, 1, 1, 0.60),
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 11,
            color: _kWhite,
          ),
        ),
      ],
    );
  }

  // ─── Pied de page ────────────────────────────────────────────────────────────

  static pw.Widget _pageFooter(pw.Context ctx, String dateLabel) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _kBorder, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'SIRIUS IoT — Rapport généré le $dateLabel',
            style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _kGray),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _kGray),
          ),
        ],
      ),
    );
  }

  // ─── Titre de section ─────────────────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title, int colorHex) {
    final color = PdfColor.fromInt(colorHex);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 16,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 11,
              color: _kText,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Ligne stats Min / Moy / Max ─────────────────────────────────────────────

  static pw.Widget _statsRow({
    required List<double> temps,
    required List<double> hums,
    required List<double> press,
    required bool hasHum,
    required bool hasPress,
  }) {
    final metrics = <_MetricInfo>[
      _MetricInfo('Température', '°C', _kAzure, temps),
      if (hasHum)  _MetricInfo('Humidité',   '%',   _kOrange, hums),
      if (hasPress) _MetricInfo('Pression',  'hPa', _kPurple, press),
    ];

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: metrics.map((m) {
          return pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kBorder),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                children: [
                  // En-tête coloré
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: pw.BoxDecoration(
                      color: m.color,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(9),
                        topRight: pw.Radius.circular(9),
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '${m.label} (${m.unit})',
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 9,
                          color: _kWhite,
                        ),
                      ),
                    ),
                  ),
                  // Stats
                  if (m.values.isEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(14),
                      child: pw.Text(
                        'Aucune donnée',
                        style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: 9,
                          color: _kGray,
                        ),
                      ),
                    )
                  else ...[
                    _statLine('Min',  _min(m.values).toStringAsFixed(2), _kGreen,  m.unit),
                    _dividerLine(),
                    _statLine('Moy',  _avg(m.values).toStringAsFixed(2), m.color,  m.unit),
                    _dividerLine(),
                    _statLine('Max',  _max(m.values).toStringAsFixed(2), _kRed,    m.unit),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _statLine(String label, String value, PdfColor color, String unit) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9, color: _kGray),
          ),
          pw.Row(
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 11, color: color),
              ),
              pw.SizedBox(width: 3),
              pw.Text(
                unit,
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _kGray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _dividerLine() =>
      pw.Container(height: 0.5, color: _kBorder);

  // ─── Tableau des relevés ─────────────────────────────────────────────────────

  static pw.Widget _dataTable(
    List<Map<String, dynamic>> rows, {
    required bool hasHum,
    required bool hasPress,
  }) {
    final headers = ['Heure', 'Température (°C)'];
    if (hasHum)   headers.add('Humidité (%)');
    if (hasPress) headers.add('Pression (hPa)');

    final colWidths = <int, pw.TableColumnWidth>{};
    colWidths[0] = const pw.FixedColumnWidth(60);
    for (int i = 1; i < headers.length; i++) {
      colWidths[i] = const pw.FlexColumnWidth();
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Table(
        columnWidths: colWidths,
        border: pw.TableBorder.all(color: _kBorder, width: 0.5),
        children: [
          // En-tête
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kAzure),
            children: headers.map((h) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 9,
                    color: _kWhite,
                  ),
                ),
              );
            }).toList(),
          ),
          // Données
          ...rows.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;
            final dt = DateTime.fromMillisecondsSinceEpoch(row['InfoDate'] as int);
            final time = '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';
            final bg = idx.isEven ? _kWhite : _kLightGray;

            final cells = <pw.Widget>[
              _cell(time, bg, bold: false, color: _kGray),
              _cell(
                row['temperature'] != null
                    ? (row['temperature'] as num).toStringAsFixed(2)
                    : '-',
                bg,
                color: _kAzure,
                bold: true,
              ),
              if (hasHum)
                _cell(
                  row['humidity'] != null
                      ? (row['humidity'] as num).toStringAsFixed(2)
                      : '-',
                  bg,
                  color: _kOrange,
                ),
              if (hasPress)
                _cell(
                  row['presure'] != null
                      ? (row['presure'] as num).toStringAsFixed(2)
                      : '-',
                  bg,
                  color: _kPurple,
                ),
            ];

            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: cells,
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    PdfColor bg, {
    bool bold = false,
    PdfColor color = _kText,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }
}

// ─── Modèle interne ───────────────────────────────────────────────────────────

class _MetricInfo {
  const _MetricInfo(this.label, this.unit, this.color, this.values);
  final String label, unit;
  final PdfColor color;
  final List<double> values;
}
