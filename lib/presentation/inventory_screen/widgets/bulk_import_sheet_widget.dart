import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/activity_log_service.dart';
import '../../../services/csv_import_service.dart';
import '../../../theme/app_theme.dart';

/// Bottom-sheet style dialog for bulk CSV import.
/// Phases: (1) idle → (2) preview → (3) importing → (4) summary
class BulkImportSheet extends StatefulWidget {
  final String storeId;
  final String userId;
  final String userName;
  final String userRole;
  final VoidCallback onImportComplete;

  const BulkImportSheet({
    super.key,
    required this.storeId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.onImportComplete,
  });

  @override
  State<BulkImportSheet> createState() => _BulkImportSheetState();
}

enum _Phase { idle, preview, importing, summary }

class _BulkImportSheetState extends State<BulkImportSheet> {
  _Phase _phase = _Phase.idle;
  List<CsvImportRow> _rows = [];
  BulkImportSummary? _summary;
  String? _pickError;
  String _fileName = '';

  // ─── File picking ─────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() {
      _pickError = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _pickError = 'Could not read file. Please try again.');
        return;
      }

      _fileName = file.name;
      final parsed = CsvImportService.instance.parseBytes(bytes);

      if (parsed.isEmpty) {
        setState(() => _pickError = 'The CSV file appears to be empty.');
        return;
      }

      // Check for header error (single row with header error)
      if (parsed.length == 1 &&
          !parsed.first.isValid &&
          parsed.first.errors.any((e) => e.contains('header'))) {
        setState(() => _pickError = parsed.first.errors.first);
        return;
      }

      setState(() {
        _rows = parsed;
        _phase = _Phase.preview;
      });
    } catch (e) {
      setState(() => _pickError = 'Failed to pick file: $e');
    }
  }

  // ─── Import execution ─────────────────────────────────────────────────────

  Future<void> _executeImport() async {
    setState(() => _phase = _Phase.importing);

    final summary = await CsvImportService.instance.executeImport(
      storeId: widget.storeId,
      updatedBy: widget.userName,
      rows: _rows,
    );

    // Log bulk import action
    if (summary.importedCount > 0) {
      await ActivityLogService.instance.log(
        storeId: widget.storeId,
        userId: widget.userId,
        userName: widget.userName,
        userRole: widget.userRole,
        actionType: ActivityActionType.bulkImport,
        details:
            'Bulk CSV import: ${summary.importedCount} items (${summary.createdCount} created, ${summary.updatedCount} updated)',
        quantity: summary.importedCount.toDouble(),
      );
    }

    setState(() {
      _summary = summary;
      _phase = _Phase.summary;
    });

    widget.onImportComplete();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            _buildTitle(),
            Flexible(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.onSurfaceMuted.withAlpha(80),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk CSV Import',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                if (_fileName.isNotEmpty)
                  Text(
                    _fileName,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            color: AppTheme.onSurfaceSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _Phase.idle:
        return _buildIdlePhase();
      case _Phase.preview:
        return _buildPreviewPhase();
      case _Phase.importing:
        return _buildImportingPhase();
      case _Phase.summary:
        return _buildSummaryPhase();
    }
  }

  // ─── Phase: Idle ──────────────────────────────────────────────────────────

  Widget _buildIdlePhase() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instructions card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: AppTheme.onSurfaceMuted.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CSV Format Requirements',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.check_circle_outline_rounded,
                  'First row must be a header row',
                ),
                _infoRow(
                  Icons.check_circle_outline_rounded,
                  'Required columns: item_name, quantity',
                ),
                _infoRow(
                  Icons.check_circle_outline_rounded,
                  'Optional column: category (auto-created if new)',
                ),
                _infoRow(
                  Icons.check_circle_outline_rounded,
                  'Quantity must be a number (decimals allowed, e.g. 5.5)',
                ),
                _infoRow(
                  Icons.info_outline_rounded,
                  'Existing items: quantity will be added to current stock',
                ),
                _infoRow(
                  Icons.info_outline_rounded,
                  'New items: will be created with given quantity',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    'item_name,quantity,category\nApple Juice,50,Beverages\nOrange Soda,5.5,Beverages\nMilk,88.9,Dairy\nRice,100',
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 11,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_pickError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pickError!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Choose CSV File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.onSurfaceMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurfaceSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase: Preview ───────────────────────────────────────────────────────

  Widget _buildPreviewPhase() {
    final validCount = _rows.where((r) => r.isValid).length;
    final invalidCount = _rows.length - validCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              _statChip(
                '${_rows.length} rows',
                Icons.table_rows_rounded,
                AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _statChip(
                '$validCount valid',
                Icons.check_circle_rounded,
                const Color(0xFF2E7D32),
              ),
              if (invalidCount > 0) ...[
                const SizedBox(width: 8),
                _statChip(
                  '$invalidCount skipped',
                  Icons.warning_rounded,
                  AppTheme.warning,
                ),
              ],
            ],
          ),
        ),
        // Table header
        Container(
          color: AppTheme.background,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#',
                  style: _headerStyle(),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text('Item Name', style: _headerStyle()),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Qty',
                  style: _headerStyle(),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: Text('Category', style: _headerStyle())),
              const SizedBox(width: 4),
              SizedBox(
                width: 50,
                child: Text(
                  'Status',
                  style: _headerStyle(),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // Table rows
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.35,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _rows.length,
            itemBuilder: (_, i) => _buildPreviewRow(_rows[i]),
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _rows = [];
                      _phase = _Phase.idle;
                      _fileName = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: validCount > 0 ? _executeImport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(
                    'Import $validCount Item${validCount == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(CsvImportRow row) {
    final isValid = row.isValid;
    final bg = isValid ? Colors.transparent : AppTheme.error.withAlpha(10);
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${row.rowIndex}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  row.rawItemName.isEmpty ? '(empty)' : row.rawItemName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isValid
                        ? AppTheme.onSurface
                        : AppTheme.onSurfaceMuted,
                    fontStyle: row.rawItemName.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  row.quantity != null
                      ? row.quantity!.toStringAsFixed(
                          row.quantity! % 1 == 0 ? 0 : 1,
                        )
                      : (row.rawQuantity.isEmpty ? '—' : row.rawQuantity),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isValid ? AppTheme.onSurface : AppTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Text(
                  row.category != null && row.category!.isNotEmpty
                      ? row.category!
                      : '—',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: row.category != null && row.category!.isNotEmpty
                        ? AppTheme.onSurfaceSecondary
                        : AppTheme.onSurfaceMuted,
                    fontStyle: row.category == null || row.category!.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 50,
                child: Center(
                  child: Icon(
                    isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 18,
                    color: isValid ? const Color(0xFF2E7D32) : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (!isValid && row.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2),
              child: Text(
                row.errors.join(' · '),
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppTheme.onSurfaceMuted,
    letterSpacing: 0.5,
  );

  // ─── Phase: Importing ─────────────────────────────────────────────────────

  Widget _buildImportingPhase() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 20),
          Text(
            'Importing items…',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppTheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please wait while we sync your data.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase: Summary ───────────────────────────────────────────────────────

  Widget _buildSummaryPhase() {
    final s = _summary!;
    final success = s.importedCount > 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: success
                  ? const Color(0xFF2E7D32).withAlpha(20)
                  : AppTheme.error.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              size: 36,
              color: success ? const Color(0xFF2E7D32) : AppTheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            success ? 'Import Complete' : 'Import Failed',
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  '${s.importedCount}',
                  'Imported',
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  '${s.createdCount}',
                  'Created',
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  '${s.updatedCount}',
                  'Updated',
                  const Color(0xFF0277BD),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryCard(
                  '${s.skippedCount}',
                  'Skipped',
                  AppTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
          if (s.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(15),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Errors (${s.errors.length})',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: s.errors
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  '• $e',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}