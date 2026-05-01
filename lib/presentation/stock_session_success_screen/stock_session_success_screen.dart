
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../../services/pdf_service.dart';
import '../../../services/stock_session_service.dart';
import '../../../theme/app_theme.dart';

/// Success screen shown after a stock session is submitted
class StockSessionSuccessScreen extends StatefulWidget {
  const StockSessionSuccessScreen({super.key});

  @override
  State<StockSessionSuccessScreen> createState() =>
      _StockSessionSuccessScreenState();
}

class _StockSessionSuccessScreenState extends State<StockSessionSuccessScreen> {
  late StockSession _session;
  late String _storeName;
  late List<String> _failedItems;
  bool _isGeneratingPdf = false;
  Uint8List? _pdfBytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    _session = args['session'] as StockSession;
    _storeName = args['storeName'] as String? ?? '';
    _failedItems = (args['failedItems'] as List<String>?) ?? [];
  }

  Future<Uint8List> _getPdfBytes() async {
    if (_pdfBytes != null) return _pdfBytes!;
    _pdfBytes = await PdfService.instance.generateSessionPdf(
      session: _session,
      storeName: _storeName,
    );
    return _pdfBytes!;
  }

  Future<void> _downloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _getPdfBytes();
      final isStockIn = _session.sessionType == 'IN';
      final fileName =
          '${isStockIn ? 'stock_in' : 'stock_out'}_${_session.createdAt.millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _getPdfBytes();
      final isStockIn = _session.sessionType == 'IN';
      final fileName =
          '${isStockIn ? 'stock_in' : 'stock_out'}_${_session.createdAt.millisecondsSinceEpoch}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isStockIn = _session.sessionType == 'IN';
    final accentColor = isStockIn ? AppTheme.secondary : AppTheme.error;
    final accentBg = isStockIn ? AppTheme.secondaryLight : AppTheme.errorLight;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Success icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: accentBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withAlpha(80),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: accentColor,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                isStockIn ? 'Stock In Complete!' : 'Stock Out Complete!',
                textAlign: TextAlign.center,
                style: GoogleFonts.fraunces(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_session.totalItems} item${_session.totalItems == 1 ? '' : 's'} updated successfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.onSurfaceSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Session info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Session Summary',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isStockIn ? 'STOCK IN' : 'STOCK OUT',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Icons.store_outlined, 'Store', _storeName),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.person_outline_rounded,
                      'Performed By',
                      '${_session.performedByName} (${_session.performedByRole})',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.calendar_today_outlined,
                      'Date & Time',
                      '${_formatDate(_session.createdAt)} · ${_formatTime(_session.createdAt)}',
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.inventory_2_outlined,
                      'Total Items',
                      '${_session.totalItems}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Failed items warning
              if (_failedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warning.withAlpha(80)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_failedItems.length} item${_failedItems.length == 1 ? '' : 's'} failed to update',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warning,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _failedItems.join(', '),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.onSurfaceSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_failedItems.isNotEmpty) const SizedBox(height: 16),

              // Items table
              if (_session.items.isNotEmpty) ...[
                Text(
                  'Items Updated',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Item',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurfaceMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Category',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurfaceMuted,
                                ),
                              ),
                            ),
                            Text(
                              'Qty',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rows
                      ...(_session.items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: i.isOdd
                                ? AppTheme.surfaceVariant.withAlpha(40)
                                : Colors.transparent,
                            border: i < _session.items.length - 1
                                ? const Border(
                                    bottom: BorderSide(
                                      color: AppTheme.outlineVariant,
                                      width: 0.5,
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.itemName,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item.category,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppTheme.onSurfaceMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${_formatQty(item.quantity)} ${item.unit}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // PDF buttons
              Text(
                'Export Report',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _sharePdf,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        'Share PDF',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _downloadPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: const Color(0xFF111113),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF111113),
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'Download PDF',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Done button
              TextButton(
                onPressed: () {
                  // Pop back to inventory
                  Navigator.of(context).popUntil(
                    (route) => route.settings.name == '/inventory-screen',
                  );
                },
                child: Text(
                  'Back to Inventory',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.onSurfaceMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
