import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/inventory_service.dart';

class StockActionSheet extends StatefulWidget {
  final InventoryItem item;
  final bool isStockIn;
  final String userRole;
  final String userName;
  final ValueChanged<double> onConfirm;

  const StockActionSheet({
    super.key,
    required this.item,
    required this.isStockIn,
    required this.userRole,
    required this.userName,
    required this.onConfirm,
  });

  @override
  State<StockActionSheet> createState() => _StockActionSheetState();
}

class _StockActionSheetState extends State<StockActionSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _qty = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _actionColor =>
      widget.isStockIn ? AppTheme.secondary : AppTheme.error;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _actionColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.isStockIn
                        ? Icons.add_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                    color: _actionColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isStockIn ? 'Stock In' : 'Stock Out',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      widget.item.name,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Stock',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    '${formatQuantity(widget.item.quantity)} ${widget.item.unit}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              // Allow decimal input to match decimal stock quantities
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (v) => setState(() => _qty = double.tryParse(v) ?? 0),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) {
                  return 'Enter a quantity greater than 0';
                }
                if (n > kMaxQuantity) {
                  return 'Quantity cannot exceed $kMaxQuantity';
                }
                // Stock Out: prevent going below zero
                if (!widget.isStockIn && n > widget.item.quantity) {
                  return 'Cannot exceed current stock (${formatQuantity(widget.item.quantity)})';
                }
                return null;
              },
              style: GoogleFonts.ibmPlexMono(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: _actionColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: 'Quantity (${widget.item.unit})',
                hintText: '0',
                hintStyle: GoogleFonts.ibmPlexMono(
                  fontSize: 28,
                  color: AppTheme.outlineVariant,
                  fontWeight: FontWeight.w700,
                ),
                suffixText: widget.item.unit,
                suffixStyle: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ),
            if (!widget.isStockIn && _qty > 0) ...[
              const SizedBox(height: 8),
              Text(
                'New stock: ${formatQuantity((widget.item.quantity - _qty).clamp(0, kMaxQuantity))} ${widget.item.unit}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ],
            if (widget.isStockIn && _qty > 0) ...[
              const SizedBox(height: 8),
              Text(
                'New stock: ${formatQuantity(widget.item.quantity + _qty)} ${widget.item.unit}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _actionColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onConfirm(_qty);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.isStockIn ? '+' : '-'}${formatQuantity(_qty)} ${widget.item.unit} — ${widget.item.name}',
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  widget.isStockIn ? 'Confirm Stock In' : 'Confirm Stock Out',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
