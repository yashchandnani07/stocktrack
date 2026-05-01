import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_badge_widget.dart';
import '../user_management_screen.dart';

class ChangeRoleSheet extends StatefulWidget {
  final AppUser user;
  final ValueChanged<String> onRoleChanged;

  const ChangeRoleSheet({
    super.key,
    required this.user,
    required this.onRoleChanged,
  });

  @override
  State<ChangeRoleSheet> createState() => _ChangeRoleSheetState();
}

class _ChangeRoleSheetState extends State<ChangeRoleSheet> {
  // TODO: Replace with Riverpod/Bloc for production
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
  }

  final List<Map<String, dynamic>> _roleOptions = [
    {
      'role': 'Manager',
      'description': 'Manage items, categories, and stock operations',
      'icon': Icons.manage_accounts_rounded,
    },
    {
      'role': 'Staff',
      'description': 'Perform stock in/out operations only',
      'icon': Icons.person_rounded,
    },
  ];

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
              Text(
                'Change Role',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const Spacer(),
              StatusBadgeWidget.role(widget.user.role),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.user.name,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 20),
          ..._roleOptions.map((opt) {
            final role = opt['role'] as String;
            final isSelected = _selectedRole == role;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedRole = role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryLight
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.outlineVariant,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withAlpha(38)
                              : AppTheme.outline.withAlpha(77),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          opt['icon'] as IconData,
                          size: 18,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.onSurface,
                              ),
                            ),
                            Text(
                              opt['description'] as String,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                color: AppTheme.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedRole == widget.user.role
                  ? null
                  : () {
                      widget.onRoleChanged(_selectedRole);
                      Navigator.pop(context);
                    },
              child: Text('Update to $_selectedRole'),
            ),
          ),
        ],
      ),
    );
  }
}
