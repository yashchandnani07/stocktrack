import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/activity_log_service.dart';
import '../../../theme/app_theme.dart';

class ActivityLogChartWidget extends StatelessWidget {
  final List<ActivityLogEntry> logs;

  const ActivityLogChartWidget({super.key, required this.logs});

  Map<String, Map<String, int>> _getDailyData() {
    final now = DateTime.now();
    final data = <String, Map<String, int>>{};
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.month}/${day.day}';
      data[key] = {'in': 0, 'out': 0};
    }
    for (final log in logs) {
      final key = '${log.createdAt.month}/${log.createdAt.day}';
      if (data.containsKey(key)) {
        if (log.actionType == ActivityActionType.stockIn) {
          data[key]!['in'] = (data[key]!['in'] ?? 0) + 1;
        } else if (log.actionType == ActivityActionType.stockOut) {
          data[key]!['out'] = (data[key]!['out'] ?? 0) + 1;
        }
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final dailyData = _getDailyData();
    final keys = dailyData.keys.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last 7 Days',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    _LegendDot(color: AppTheme.secondary, label: 'In'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppTheme.error, label: 'Out'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 6,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: AppTheme.onSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()}',
                          GoogleFonts.ibmPlexSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= keys.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              keys[idx],
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 9,
                                color: AppTheme.onSurfaceMuted,
                              ),
                            ),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppTheme.outlineVariant,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(keys.length, (i) {
                    final key = keys[i];
                    final inCount = dailyData[key]!['in']!.toDouble();
                    final outCount = dailyData[key]!['out']!.toDouble();
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: inCount,
                          color: AppTheme.secondary,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: outCount,
                          color: AppTheme.error,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                      barsSpace: 3,
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
