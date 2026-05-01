import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/inventory_service.dart';

class InventorySummaryWidget extends StatelessWidget {
  final List<InventoryItem> items;

  const InventorySummaryWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final outOfStock = items.where((i) => i.quantity == 0).length;
    final lowStock = items
        .where((i) => i.quantity > 0 && i.quantity <= i.lowStockThreshold)
        .length;
    final inStock = total - outOfStock - lowStock;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _SummaryChip(
            label: '$total',
            sublabel: 'Items',
            color: AppTheme.onSurfaceSecondary,
            bgColor: AppTheme.surfaceVariant,
            borderColor: AppTheme.outline,
          ),
          const SizedBox(width: 8),
          if (outOfStock > 0) ...[
            _SummaryChip(
              label: '$outOfStock',
              sublabel: 'Out',
              color: AppTheme.error,
              bgColor: AppTheme.error.withAlpha(18),
              borderColor: AppTheme.error.withAlpha(60),
            ),
            const SizedBox(width: 8),
          ],
          if (lowStock > 0) ...[
            _SummaryChip(
              label: '$lowStock',
              sublabel: 'Low',
              color: AppTheme.warning,
              bgColor: AppTheme.warning.withAlpha(18),
              borderColor: AppTheme.warning.withAlpha(60),
            ),
            const SizedBox(width: 8),
          ],
          _SummaryChip(
            label: '$inStock',
            sublabel: 'OK',
            color: AppTheme.secondary,
            bgColor: AppTheme.secondary.withAlpha(18),
            borderColor: AppTheme.secondary.withAlpha(60),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _SummaryChip({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            sublabel,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}
