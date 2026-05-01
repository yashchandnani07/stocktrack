import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/activity_log_service.dart';
import '../../../theme/app_theme.dart';

class RecentActivityWidget extends StatefulWidget {
  final String userRole;
  final String userId;
  final String userName;
  final String storeId;

  const RecentActivityWidget({
    super.key,
    required this.userRole,
    required this.userId,
    required this.userName,
    this.storeId = '',
  });

  @override
  State<RecentActivityWidget> createState() => _RecentActivityWidgetState();
}

class _RecentActivityWidgetState extends State<RecentActivityWidget> {
  List<ActivityLogEntry> _recentLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    if (widget.storeId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      List<String>? actionTypes;
      if (widget.userRole == 'Manager') {
        actionTypes = [ActivityActionType.stockIn, ActivityActionType.stockOut];
      } else if (widget.userRole == 'Staff') {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final logs = await ActivityLogService.instance.fetchRecentLogs(
        storeId: widget.storeId,
        count: 5,
      );
      if (mounted) {
        setState(() {
          _recentLogs = logs.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _actionIcon(String actionType) {
    switch (actionType) {
      case ActivityActionType.stockIn:
        return Icons.arrow_downward_rounded;
      case ActivityActionType.stockOut:
        return Icons.arrow_upward_rounded;
      case ActivityActionType.itemCreated:
        return Icons.add_box_outlined;
      case ActivityActionType.itemEdited:
        return Icons.edit_outlined;
      case ActivityActionType.itemDeleted:
        return Icons.delete_outline_rounded;
      default:
        return Icons.manage_accounts_outlined;
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
      default:
        return AppTheme.accentPurple;
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == 'Staff') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'RECENT ACTIVITY',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (_recentLogs.isNotEmpty)
                  Text(
                    'Last ${_recentLogs.length}',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: AppTheme.outlineVariant),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            )
          else if (_recentLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No recent activity',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            )
          else
            ...List.generate(_recentLogs.length, (i) {
              final log = _recentLogs[i];
              final color = _actionColor(log.actionType);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withAlpha(50)),
                          ),
                          child: Icon(
                            _actionIcon(log.actionType),
                            size: 14,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            log.humanReadable,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.onSurface,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatRelativeTime(log.createdAt),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _recentLogs.length - 1)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 58),
                      color: AppTheme.outlineVariant,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
