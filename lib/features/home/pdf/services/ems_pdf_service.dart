import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice.dart';

class EmsPdfService {
  Future<Uint8List> generateEMSPDF(
    Invoice invoice,
    String name,
    String macAddrs,
    String type,
  ) async {
    final pdf = pw.Document();
    List<pw.Widget> widgets = [];
    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(macAddrs),
        pw.SizedBox(height: 1 * PdfPageFormat.mm),
      ],
    );
    buildInvoice(Invoice invoice) {
      final headers = ['id', 'Date', 'Temperature', 'Humidité', 'Pression'];
      final data =
          invoice.items.map((item) {
            return [
              item.id,
              item.date,
              '${item.temperature}°C',
              '${item.humidity}%',
              '${item.pression}hPa',
            ];
          }).toList();
      final headers2 = ['id', 'Date', 'Temperature'];
      final data2 =
          invoice.items.map((item) {
            return [item.id, item.date, '${item.temperature}°C'];
          }).toList();

      return pw.Table.fromTextArray(
        headers: type == '1' ? headers : headers2,
        data: type == '1' ? data : data2,
        border: null,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
        cellHeight: 30,
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
      );
    }

    widgets.add(header);
    widgets.add(buildInvoice(invoice));
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  Future<void> savePdfFile(String fileName, Uint8List byteList) async {
    final output = await getTemporaryDirectory();
    var filePath = "${output.path}/$fileName.pdf";
    final file = File(filePath);
    await file.writeAsBytes(byteList);
    await OpenFile.open(filePath);
  }
}
