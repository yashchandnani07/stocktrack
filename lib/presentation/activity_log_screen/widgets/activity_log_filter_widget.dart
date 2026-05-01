import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ActivityLogFilterWidget extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final int inCount;
  final int outCount;

  const ActivityLogFilterWidget({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.inCount,
    required this.outCount,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'label': 'All', 'count': inCount + outCount},
      {'label': 'In', 'count': inCount},
      {'label': 'Out', 'count': outCount},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final label = f['label'] as String;
          final count = f['count'] as int;
          final isSelected = selected == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (label == 'In'
                            ? AppTheme.secondaryLight
                            : label == 'Out'
                            ? AppTheme.errorLight
                            : AppTheme.primary)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? (label == 'In'
                              ? AppTheme.secondary
                              : label == 'Out'
                              ? AppTheme.error
                              : AppTheme.primary)
                        : AppTheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? (label == 'In'
                                  ? AppTheme.secondary
                                  : label == 'Out'
                                  ? AppTheme.error
                                  : Colors.white)
                            : AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withAlpha(77)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (label == 'All'
                                    ? Colors.white
                                    : label == 'In'
                                    ? AppTheme.secondary
                                    : AppTheme.error)
                              : AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
