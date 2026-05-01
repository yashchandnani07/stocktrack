import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class InviteUserSheet extends StatefulWidget {
  final Function(String name, String email, String role, String contact)
  onInvite;

  const InviteUserSheet({super.key, required this.onInvite});

  @override
  State<InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends State<InviteUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  String _selectedRole = 'Staff';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Staff Member',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in the details to add a new team member.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  color: AppTheme.onSurface,
                ),
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email address';
                  return null;
                },
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  color: AppTheme.onSurface,
                ),
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  color: AppTheme.onSurface,
                ),
                decoration: const InputDecoration(
                  labelText: 'Contact Number (optional)',
                  hintText: '+1 555-000-0000',
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.outlineVariant),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.onSurfaceMuted,
                          size: 20,
                        ),
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.onSurface,
                        ),
                        items: ['Manager', 'Staff']
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 15,
                                    color: AppTheme.onSurface,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRole = v!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _RolePermissionHint(role: _selectedRole),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _isLoading = true);
                          await Future.delayed(
                            const Duration(milliseconds: 400),
                          );
                          if (mounted) {
                            setState(() => _isLoading = false);
                            widget.onInvite(
                              _nameController.text.trim(),
                              _emailController.text.trim(),
                              _selectedRole,
                              _contactController.text.trim(),
                            );
                            Navigator.pop(context);
                          }
                        },
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_rounded, size: 16),
                  label: Text(_isLoading ? 'Adding…' : 'Add Staff Member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePermissionHint extends StatelessWidget {
  final String role;
  const _RolePermissionHint({required this.role});

  @override
  Widget build(BuildContext context) {
    final String hint;
    final IconData icon;
    final Color color;

    if (role == 'Manager') {
      hint =
          'Can create/edit items, manage categories, and perform stock actions. Cannot delete critical data or manage users.';
      icon = Icons.manage_accounts_rounded;
      color = AppTheme.warning;
    } else {
      hint =
          'Can only perform stock in/out operations. Cannot create, edit, or delete items.';
      icon = Icons.person_rounded;
      color = AppTheme.onSurfaceSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
