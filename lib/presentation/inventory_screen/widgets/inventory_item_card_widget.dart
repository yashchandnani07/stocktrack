import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/inventory_service.dart';
import '../../../widgets/status_badge_widget.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final String userRole;
  final VoidCallback? onStockIn;
  final VoidCallback? onStockOut;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const InventoryItemCard({
    super.key,
    required this.item,
    required this.userRole,
    this.onStockIn,
    this.onStockOut,
    this.onEdit,
    this.onDelete,
  });

  StockStatus get _stockStatus {
    if (item.quantity == 0) return StockStatus.outOfStock;
    if (item.quantity <= item.lowStockThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  Color get _statusBorderColor {
    switch (_stockStatus) {
      case StockStatus.outOfStock:
        return AppTheme.error.withAlpha(120);
      case StockStatus.lowStock:
        return AppTheme.warning.withAlpha(120);
      case StockStatus.inStock:
        return AppTheme.outlineVariant;
    }
  }

  Color get _cardBackground {
    switch (_stockStatus) {
      case StockStatus.outOfStock:
        return const Color(0xFF1E1414);
      case StockStatus.lowStock:
        return const Color(0xFF1E1A10);
      case StockStatus.inStock:
        return AppTheme.surface;
    }
  }

  Color get _quantityColor {
    switch (_stockStatus) {
      case StockStatus.outOfStock:
        return AppTheme.error;
      case StockStatus.lowStock:
        return AppTheme.warning;
      case StockStatus.inStock:
        return AppTheme.onSurface;
    }
  }

  Color get _categoryColor {
    const colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.warning,
      AppTheme.accentPurple,
      AppTheme.accentBlue,
    ];
    return colors[item.category.hashCode.abs() % colors.length];
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'electronics':
        return Icons.devices_rounded;
      case 'stationery':
        return Icons.edit_rounded;
      case 'furniture':
        return Icons.chair_rounded;
      case 'hygiene':
        return Icons.sanitizer_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isLowOrOut = _stockStatus != StockStatus.inStock;
    final catColor = _categoryColor;

    return Container(
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusBorderColor,
          width: isLowOrOut ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.primary.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: catColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: catColor.withAlpha(50)),
                    ),
                    child: Icon(
                      _categoryIcon(item.category),
                      size: 19,
                      color: catColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_stockStatus == StockStatus.outOfStock)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 15,
                                  color: AppTheme.error,
                                ),
                              )
                            else if (_stockStatus == StockStatus.lowStock)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 15,
                                  color: AppTheme.warning,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.category,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.onSurfaceMuted,
                              ),
                            ),
                            if (item.barcode != null) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.qr_code_rounded,
                                size: 11,
                                color: AppTheme.onSurfaceMuted,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatQuantity(item.quantity),
                            style: GoogleFonts.dmSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _quantityColor,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.unit,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      StatusBadgeWidget.stockStatus(_stockStatus),
                    ],
                  ),
                ],
              ),
              if (_stockStatus != StockStatus.inStock) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _stockStatus == StockStatus.outOfStock
                        ? AppTheme.error.withAlpha(18)
                        : AppTheme.warning.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _stockStatus == StockStatus.outOfStock
                          ? AppTheme.error.withAlpha(60)
                          : AppTheme.warning.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _stockStatus == StockStatus.outOfStock
                            ? Icons.remove_circle_outline_rounded
                            : Icons.trending_down_rounded,
                        size: 12,
                        color: _stockStatus == StockStatus.outOfStock
                            ? AppTheme.error
                            : AppTheme.warning,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _stockStatus == StockStatus.outOfStock
                            ? 'Out of stock — restock needed'
                            : 'Low stock — threshold: ${item.lowStockThreshold} ${item.unit}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _stockStatus == StockStatus.outOfStock
                              ? AppTheme.error
                              : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Updated ${_timeAgo(item.lastUpdated)} by ${item.updatedBy}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppTheme.onSurfaceMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (userRole != 'Staff') ...[
                    _ActionButton(
                      icon: Icons.add_rounded,
                      color: AppTheme.secondary,
                      onTap: onStockIn,
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      icon: Icons.remove_rounded,
                      color: AppTheme.error,
                      onTap: onStockOut,
                    ),
                  ],
                  if (userRole == 'Owner') ...[
                    const SizedBox(width: 6),
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.onSurfaceMuted,
                      onTap: onDelete,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
