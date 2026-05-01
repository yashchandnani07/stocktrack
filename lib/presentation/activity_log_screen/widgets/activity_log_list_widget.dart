import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/activity_log_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';

/// Paginated, lazy-loading activity log list.
/// Accepts the first page of logs and a callback to load more pages.
class ActivityLogListWidget extends StatefulWidget {
  final List<ActivityLogEntry> logs;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const ActivityLogListWidget({
    super.key,
    required this.logs,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  State<ActivityLogListWidget> createState() => _ActivityLogListWidgetState();
}

class _ActivityLogListWidgetState extends State<ActivityLogListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    // Trigger load-more when within 200px of the bottom
    if (current >= maxScroll - 200 && widget.hasMore && !widget.isLoadingMore) {
      widget.onLoadMore();
    }
  }

  // Group flat list into date-keyed map preserving order
  Map<String, List<ActivityLogEntry>> _buildGroups(
    List<ActivityLogEntry> logs,
  ) {
    final grouped = <String, List<ActivityLogEntry>>{};
    for (final log in logs) {
      final key = _dateLabel(log.createdAt);
      grouped.putIfAbsent(key, () => []).add(log);
    }
    return grouped;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(logDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}';
  }

  String _monthName(int m) {
    const months = [
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
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (widget.logs.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No activity yet',
        subtitle: 'Actions will appear here once recorded.',
      );
    }

    final grouped = _buildGroups(widget.logs);
    final groups = grouped.entries.toList();

    // Build a flat item list: [header, item, item, ..., header, item, ...]
    // plus a footer row for load-more indicator
    final List<_ListItem> items = [];
    for (final group in groups) {
      items.add(_ListItem.header(group.key));
      for (final log in group.value) {
        items.add(_ListItem.entry(log));
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      // +1 for the footer (load-more / end indicator)
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        // Footer
        if (index == items.length) {
          return _buildFooter();
        }

        final item = items[index];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.headerLabel!.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          );
        }

        // Entry item — animate only the first 20 items to avoid jank
        final log = item.log!;
        final shouldAnimate = index < 20;
        final child = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ActivityLogItem(log: log),
        );

        if (!shouldAnimate) return child;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + (index * 20).clamp(0, 300)),
          curve: Curves.easeOutCubic,
          builder: (_, v, c) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - v)),
              child: c,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildFooter() {
    if (widget.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
        ),
      );
    }
    if (!widget.hasMore && widget.logs.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '— ${widget.logs.length} entries loaded —',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Simple discriminated union for list items
class _ListItem {
  final bool isHeader;
  final String? headerLabel;
  final ActivityLogEntry? log;

  const _ListItem._({required this.isHeader, this.headerLabel, this.log});

  factory _ListItem.header(String label) =>
      _ListItem._(isHeader: true, headerLabel: label);

  factory _ListItem.entry(ActivityLogEntry log) =>
      _ListItem._(isHeader: false, log: log);
}

class _ActivityLogItem extends StatelessWidget {
  final ActivityLogEntry log;

  const _ActivityLogItem({required this.log});

  IconData _actionIcon(String actionType) {
    switch (actionType) {
      case ActivityActionType.stockIn:
        return Icons.add_rounded;
      case ActivityActionType.stockOut:
        return Icons.remove_rounded;
      case ActivityActionType.itemCreated:
        return Icons.add_box_outlined;
      case ActivityActionType.itemEdited:
        return Icons.edit_outlined;
      case ActivityActionType.itemDeleted:
        return Icons.delete_outline_rounded;
      case ActivityActionType.userAdded:
        return Icons.person_add_outlined;
      case ActivityActionType.userRemoved:
        return Icons.person_remove_outlined;
      case ActivityActionType.roleChanged:
        return Icons.manage_accounts_outlined;
      case ActivityActionType.userEnabled:
        return Icons.check_circle_outline_rounded;
      case ActivityActionType.userDisabled:
        return Icons.block_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _actionColor(String actionType) {
    switch (actionType) {
      case ActivityActionType.stockIn:
        return AppTheme.secondary;
      case ActivityActionType.stockOut:
        return AppTheme.error;
      case ActivityActionType.itemCreated:
        return AppTheme.primary;
      case ActivityActionType.itemEdited:
        return AppTheme.warning;
      case ActivityActionType.itemDeleted:
        return AppTheme.error;
      case ActivityActionType.userAdded:
        return AppTheme.secondary;
      case ActivityActionType.userRemoved:
        return AppTheme.error;
      case ActivityActionType.roleChanged:
        return AppTheme.warning;
      case ActivityActionType.userEnabled:
        return AppTheme.secondary;
      case ActivityActionType.userDisabled:
        return AppTheme.onSurfaceMuted;
      default:
        return AppTheme.primary;
    }
  }

  Color _actionBg(String actionType) {
    final color = _actionColor(actionType);
    return color.withAlpha(4590);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Owner':
        return AppTheme.primary;
      case 'Manager':
        return AppTheme.warning;
      default:
        return AppTheme.onSurfaceMuted;
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(log.actionType);
    final bg = _actionBg(log.actionType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color.withAlpha(12750)),
            ),
            child: Icon(_actionIcon(log.actionType), size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.humanReadable,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurface,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _roleColor(log.userRole),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.userRole,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppTheme.onSurfaceMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (log.quantity != null && log.unit != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${log.actionType == ActivityActionType.stockIn
                            ? '+'
                            : log.actionType == ActivityActionType.stockOut
                            ? '-'
                            : ''}${log.quantity} ${log.unit}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatTime(log.createdAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
