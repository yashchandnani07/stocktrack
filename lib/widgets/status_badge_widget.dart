import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum StockStatus { inStock, lowStock, outOfStock }

class StatusBadgeWidget extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final double fontSize;

  const StatusBadgeWidget({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.fontSize = 11,
  });

  factory StatusBadgeWidget.stockStatus(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return StatusBadgeWidget(
          label: 'In Stock',
          backgroundColor: AppTheme.secondary.withAlpha(18),
          textColor: AppTheme.secondary,
          borderColor: AppTheme.secondary.withAlpha(60),
        );
      case StockStatus.lowStock:
        return StatusBadgeWidget(
          label: 'Low Stock',
          backgroundColor: AppTheme.warning.withAlpha(18),
          textColor: AppTheme.warning,
          borderColor: AppTheme.warning.withAlpha(60),
        );
      case StockStatus.outOfStock:
        return StatusBadgeWidget(
          label: 'Out of Stock',
          backgroundColor: AppTheme.error.withAlpha(18),
          textColor: AppTheme.error,
          borderColor: AppTheme.error.withAlpha(60),
        );
    }
  }

  factory StatusBadgeWidget.actionIn() {
    return StatusBadgeWidget(
      label: 'STOCK IN',
      backgroundColor: AppTheme.secondary.withAlpha(18),
      textColor: AppTheme.secondary,
      borderColor: AppTheme.secondary.withAlpha(60),
    );
  }

  factory StatusBadgeWidget.actionOut() {
    return StatusBadgeWidget(
      label: 'STOCK OUT',
      backgroundColor: AppTheme.error.withAlpha(18),
      textColor: AppTheme.error,
      borderColor: AppTheme.error.withAlpha(60),
    );
  }

  factory StatusBadgeWidget.role(String role) {
    Color bg;
    Color fg;
    switch (role) {
      case 'Owner':
        bg = AppTheme.primary.withAlpha(20);
        fg = AppTheme.primary;
        break;
      case 'Manager':
        bg = AppTheme.secondary.withAlpha(20);
        fg = AppTheme.secondary;
        break;
      default:
        bg = AppTheme.accentBlue.withAlpha(20);
        fg = AppTheme.accentBlue;
    }
    return StatusBadgeWidget(
      label: role,
      backgroundColor: bg,
      textColor: fg,
      borderColor: fg.withAlpha(60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class AppThemeExtension {
  static Color get onSurfaceSecondary => AppTheme.onSurfaceSecondary;
}
