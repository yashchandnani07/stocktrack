import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_badge_widget.dart';
import '../user_management_screen.dart';

class UserListItemWidget extends StatelessWidget {
  final AppUser user;
  final String currentUserRole;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;

  const UserListItemWidget({
    super.key,
    required this.user,
    required this.currentUserRole,
    required this.onTap,
    required this.onToggleStatus,
    required this.onRemove,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _avatarColor(String name) {
    const colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.warning,
      AppTheme.accentPurple,
      AppTheme.accentBlue,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final canChange = currentUserRole == 'Owner' && user.role != 'Owner';
    final color = _avatarColor(user.name);
    final isDisabled = !user.isActive;

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled ? AppTheme.outline : AppTheme.outline,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: canChange ? onTap : null,
              borderRadius: canChange
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
              splashColor: AppTheme.primary.withAlpha(15),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withAlpha(22),
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withAlpha(60)),
                          ),
                          child: Center(
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : 'U',
                              style: GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: user.isActive
                                  ? AppTheme.secondary
                                  : AppTheme.onSurfaceMuted,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                                  user.name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDisabled)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withAlpha(18),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: AppTheme.error.withAlpha(60),
                                    ),
                                  ),
                                  child: Text(
                                    'Disabled',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.onSurfaceMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user.contact.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 10,
                                  color: AppTheme.onSurfaceMuted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  user.contact,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: AppTheme.onSurfaceMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Active ${_timeAgo(user.lastActive)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: AppTheme.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadgeWidget.role(user.role),
                        if (canChange) ...[
                          const SizedBox(height: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (canChange) ...[
              Container(height: 1, color: AppTheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _ActionChip(
                      icon: user.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      label: user.isActive ? 'Disable' : 'Enable',
                      color: user.isActive
                          ? AppTheme.warning
                          : AppTheme.secondary,
                      onTap: onToggleStatus,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.person_remove_rounded,
                      label: 'Remove',
                      color: AppTheme.error,
                      onTap: onRemove,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
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
      ),
    );
  }
}
