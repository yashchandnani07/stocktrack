import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/stock_session_service.dart';

/// Service for generating stock session PDF reports
class PdfService {
  static PdfService? _instance;
  static PdfService get instance => _instance ??= PdfService._();
  PdfService._();

  /// Generate a PDF for a stock session and return bytes
  Future<Uint8List> generateSessionPdf({
    required StockSession session,
    required String storeName,
  }) async {
    final pdf = pw.Document();
    final isStockIn = session.sessionType == 'IN';
    final title = isStockIn ? 'Stock In Report' : 'Stock Out Report';
    final accentColor = isStockIn
        ? PdfColor.fromHex('#4CAF82')
        : PdfColor.fromHex('#E05252');
    final headerBg = PdfColor.fromHex('#1C1C1E');
    final rowAlt = PdfColor.fromHex('#F5F5F5');

    final dateStr = _formatDate(session.createdAt);
    final timeStr = _formatTime(session.createdAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      storeName,
                      style: pw.TextStyle(
                        fontSize: 13,
                        color: PdfColor.fromHex('#D4A853'),
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    isStockIn ? 'STOCK IN' : 'STOCK OUT',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Info row
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                _infoCell('Date', dateStr),
                _divider(),
                _infoCell('Time', timeStr),
                _divider(),
                _infoCell('Performed By', session.performedByName),
                _divider(),
                _infoCell('Role', session.performedByRole),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Items table
          pw.Text(
            'Items',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#111113'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#E0E0E0'),
              width: 0.5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Table header
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2C2C2E'),
                ),
                children: [
                  _tableHeader('Item Name'),
                  _tableHeader('Category'),
                  _tableHeader('Quantity'),
                ],
              ),
              // Table rows
              ...session.items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final bg = i.isOdd ? rowAlt : PdfColors.white;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _tableCell(item.itemName),
                    _tableCell(item.category),
                    _tableCell('${_formatQty(item.quantity)} ${item.unit}'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F9F9F9'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Items in Session',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${session.items.length}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Footer
          pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated by StockTrack · $dateStr $timeStr',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#9E9E9E'),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _infoCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('#9E9E9E'),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _divider() {
    return pw.Container(
      width: 1,
      height: 30,
      color: PdfColor.fromHex('#E0E0E0'),
      margin: const pw.EdgeInsets.symmetric(horizontal: 8),
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    final s = qty.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
}
