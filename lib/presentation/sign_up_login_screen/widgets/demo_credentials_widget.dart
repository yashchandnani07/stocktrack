import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class DemoCredentialsWidget extends StatelessWidget {
  final bool isLogin;

  const DemoCredentialsWidget({super.key, required this.isLogin});

  static final List<Map<String, String>> _credentials = [
    {
      'role': 'Owner',
      'email': 'amara.osei@stocktrack.io',
      'password': 'owner@2026',
    },
    {
      'role': 'Manager',
      'email': 'priya.sharma@stocktrack.io',
      'password': 'manager@2026',
    },
    {
      'role': 'Staff',
      'email': 'carlos.mendez@stocktrack.io',
      'password': 'staff@2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                'DEMO ACCOUNTS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._credentials.map((cred) => _CredentialRow(credential: cred)),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final Map<String, String> credential;

  const _CredentialRow({required this.credential});

  Color _roleColor(String role) {
    switch (role) {
      case 'Owner':
        return AppTheme.primary;
      case 'Manager':
        return AppTheme.secondary;
      default:
        return AppTheme.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(credential['role']!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Text(
              credential['role']!,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credential['email']!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppTheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  credential['password']!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${credential['role']} credentials copied',
                    style: GoogleFonts.dmSans(fontSize: 13),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.copy_rounded,
                size: 13,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}