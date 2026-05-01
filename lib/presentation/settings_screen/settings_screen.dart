import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/activity_log_service.dart';
import '../../services/permission_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../user_management_screen/user_management_screen.dart';
import '../user_management_screen/widgets/change_role_sheet_widget.dart';
import '../user_management_screen/widgets/invite_user_sheet_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userRole = 'Owner';
  String _userName = '';
  String _userId = '';
  String _storeId = '';
  String _storeName = '';
  bool _isActive = true;

  bool _isLoadingMembers = true;
  bool _isEditingStoreName = false;
  bool _isSavingName = false;
  List<AppUser> _members = [];

  final TextEditingController _storeNameController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final newRole = args['role'] as String? ?? 'Staff';
      final newStoreId =
          args['storeId'] as String? ??
          StoreService.instance.currentStore?.id ??
          '';
      final storeChanged = newStoreId != _storeId;
      final roleChanged = newRole != _userRole;

      _userRole = newRole;
      _userName = args['userName'] as String? ?? '';
      _userId = args['userId'] as String? ?? '';
      _isActive = args['isActive'] as bool? ?? true;
      _storeId = newStoreId;
      _storeName =
          args['storeName'] as String? ??
          StoreService.instance.currentStore?.name ??
          '';
      PermissionService.instance.setUser(
        role: _userRole,
        userId: _userId,
        isActive: _isActive,
        storeId: _storeId,
      );
    }
    _storeNameController.text = _storeName;
    if (_storeId.isNotEmpty && _isLoadingMembers) {
      _loadMembers();
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (_storeId.isEmpty) return;
    setState(() => _isLoadingMembers = true);
    final members = await StoreService.instance.fetchStoreMembers(_storeId);
    if (mounted) {
      setState(() {
        _members = members.map(AppUser.fromMember).toList();
        _isLoadingMembers = false;
      });
    }
  }

  Future<void> _saveStoreName() async {
    final newName = _storeNameController.text.trim();
    if (newName.isEmpty || newName == _storeName) {
      setState(() => _isEditingStoreName = false);
      return;
    }
    setState(() => _isSavingName = true);
    try {
      await StoreService.instance.client
          .from('stores')
          .update({'name': newName})
          .eq('id', _storeId);
      if (mounted) {
        setState(() {
          _storeName = newName;
          _isEditingStoreName = false;
          _isSavingName = false;
        });
        // Update the current store in service
        final current = StoreService.instance.currentStore;
        if (current != null) {
          StoreService.instance.setCurrentStore(
            StoreModel(
              id: current.id,
              name: newName,
              ownerId: current.ownerId,
              createdAt: current.createdAt,
            ),
            _userRole,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store name updated to "$newName"'),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update store name: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showChangeRoleSheet(AppUser user) {
    if (_userRole != 'Owner') return;
    if (user.role == 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner role cannot be changed.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeRoleSheet(
        user: user,
        onRoleChanged: (newRole) async {
          final oldRole = user.role;
          final success = await StoreService.instance.updateMemberRole(
            memberId: user.id,
            newRole: newRole,
            storeId: _storeId,
          );
          if (success && mounted) {
            setState(() => user.role = newRole);
            ActivityLogService.instance.log(
              storeId: _storeId,
              userId: _userId,
              userName: _userName,
              userRole: _userRole,
              actionType: ActivityActionType.roleChanged,
              details: '${user.name}: $oldRole → $newRole',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${user.name}\'s role updated to $newRole'),
                backgroundColor: AppTheme.secondary,
              ),
            );
          }
        },
      ),
    );
  }

  void _showInviteSheet() {
    if (_userRole != 'Owner') return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteUserSheet(
        onInvite: (name, email, role, contact) async {
          final error = await StoreService.instance.inviteMember(
            storeId: _storeId,
            email: email,
            role: role,
          );
          if (!mounted) return;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: AppTheme.error),
            );
            return;
          }
          await _loadMembers();
          ActivityLogService.instance.log(
            storeId: _storeId,
            userId: _userId,
            userName: _userName,
            userRole: _userRole,
            actionType: ActivityActionType.userAdded,
            details: '$email as $role',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$email invited as $role'),
              backgroundColor: AppTheme.secondary,
            ),
          );
        },
      ),
    );
  }

  void _confirmRemoveMember(AppUser user) {
    if (_userRole != 'Owner') return;
    if (user.role == 'Owner') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Owner cannot be removed.')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Member',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        content: Text(
          'Remove ${user.name} from this store? They will lose all access.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppTheme.onSurfaceSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: AppTheme.onSurfaceMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await StoreService.instance.removeMember(
                user.id,
                _storeId,
              );
              if (success && mounted) {
                setState(() => _members.remove(user));
                ActivityLogService.instance.log(
                  storeId: _storeId,
                  userId: _userId,
                  userName: _userName,
                  userRole: _userRole,
                  actionType: ActivityActionType.userRemoved,
                  details: '${user.name} (${user.role})',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${user.name} removed from store')),
                );
              }
            },
            child: Text(
              'Remove',
              style: GoogleFonts.dmSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmToggleStatus(AppUser user) {
    if (_userRole != 'Owner') return;
    if (user.role == 'Owner') return;
    final action = user.isActive ? 'disable' : 'enable';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${action[0].toUpperCase()}${action.substring(1)} Account',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        content: Text(
          user.isActive
              ? 'Disable ${user.name}? They will not be able to access this store.'
              : 'Enable ${user.name}? They will regain access to this store.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppTheme.onSurfaceSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: AppTheme.onSurfaceMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final wasActive = user.isActive;
              final success = await StoreService.instance.toggleMemberStatus(
                memberId: user.id,
                isActive: !wasActive,
                storeId: _storeId,
              );
              if (success && mounted) {
                setState(() => user.isActive = !wasActive);
                ActivityLogService.instance.log(
                  storeId: _storeId,
                  userId: _userId,
                  userName: _userName,
                  userRole: _userRole,
                  actionType: wasActive
                      ? ActivityActionType.userDisabled
                      : ActivityActionType.userEnabled,
                  details: user.name,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${user.name} ${user.isActive ? 'enabled' : 'disabled'}',
                    ),
                  ),
                );
              }
            },
            child: Text(
              '${action[0].toUpperCase()}${action.substring(1)}',
              style: TextStyle(
                color: user.isActive ? AppTheme.error : AppTheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    const navIndex = 3;

    final body = SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildStoreDetailsSection()),
          SliverToBoxAdapter(child: _buildCollaboratorsHeader()),
          if (_isLoadingMembers)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final roleOrder = {'Owner': 0, 'Manager': 1, 'Staff': 2};
                final sorted = [..._members]
                  ..sort(
                    (a, b) => (roleOrder[a.role] ?? 3).compareTo(
                      roleOrder[b.role] ?? 3,
                    ),
                  );
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: 200 + (i * 40).clamp(0, 300),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _CollaboratorCard(
                      user: sorted[i],
                      isOwner: _userRole == 'Owner',
                      currentUserId: _userId,
                      onChangeRole: () => _showChangeRoleSheet(sorted[i]),
                      onToggleStatus: () => _confirmToggleStatus(sorted[i]),
                      onRemove: () => _confirmRemoveMember(sorted[i]),
                    ),
                  ),
                );
              }, childCount: _members.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: isTablet
          ? null
          : AppNavigation(
              currentIndex: navIndex,
              userRole: _userRole,
              userName: _userName,
              userId: _userId,
              isActive: _isActive,
              storeId: _storeId,
              storeName: _storeName,
            ),
      body: isTablet
          ? Row(
              children: [
                AppNavigation(
                  currentIndex: navIndex,
                  userRole: _userRole,
                  userName: _userName,
                  userId: _userId,
                  isActive: _isActive,
                  storeId: _storeId,
                  storeName: _storeName,
                ),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: GoogleFonts.fraunces(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _storeName.isNotEmpty ? _storeName : 'Store configuration',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetailsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Store Details'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              children: [
                _buildStoreNameRow(),
                Divider(height: 1, color: AppTheme.outlineVariant),
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Your Role',
                  value: _userRole,
                  valueColor: _roleColor(_userRole),
                ),
                Divider(height: 1, color: AppTheme.outlineVariant),
                _buildInfoRow(
                  icon: Icons.people_outline_rounded,
                  label: 'Members',
                  value: _isLoadingMembers
                      ? '—'
                      : '${_members.length} collaborator${_members.length == 1 ? '' : 's'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreNameRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _isEditingStoreName
                ? TextField(
                    controller: _storeNameController,
                    autofocus: true,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _saveStoreName(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Name',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.onSurfaceMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _storeName.isNotEmpty ? _storeName : '—',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          if (_userRole == 'Owner') ...[
            const SizedBox(width: 8),
            if (_isEditingStoreName)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSavingName)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  else ...[
                    GestureDetector(
                      onTap: () => setState(() {
                        _isEditingStoreName = false;
                        _storeNameController.text = _storeName;
                      }),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _saveStoreName,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ],
              )
            else
              GestureDetector(
                onTap: () => setState(() => _isEditingStoreName = true),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.onSurfaceMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaboratorsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Expanded(child: _SectionLabel(label: 'Collaborators')),
          if (_userRole == 'Owner')
            GestureDetector(
              onTap: _showInviteSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Invite',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurfaceMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _CollaboratorCard extends StatelessWidget {
  final AppUser user;
  final bool isOwner;
  final String currentUserId;
  final VoidCallback onChangeRole;
  final VoidCallback onToggleStatus;
  final VoidCallback onRemove;

  const _CollaboratorCard({
    required this.user,
    required this.isOwner,
    required this.currentUserId,
    required this.onChangeRole,
    required this.onToggleStatus,
    required this.onRemove,
  });

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

  Color _roleBg(String role) {
    switch (role) {
      case 'Owner':
        return AppTheme.primaryLight;
      case 'Manager':
        return AppTheme.secondaryLight;
      default:
        return const Color(0xFF1A2035);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = user.userId == currentUserId;
    final isDisabled = !user.isActive;

    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? AppTheme.surface.withAlpha(180) : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDisabled
              ? AppTheme.outlineVariant.withAlpha(120)
              : AppTheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _roleBg(user.role),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _roleColor(user.role).withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  _initials(user.name),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _roleColor(user.role),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name + (isSelf ? ' (You)' : ''),
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDisabled
                                ? AppTheme.onSurfaceMuted
                                : AppTheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDisabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(4),
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _roleBg(user.role),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _roleColor(user.role).withAlpha(50)),
              ),
              child: Text(
                user.role,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _roleColor(user.role),
                ),
              ),
            ),
            // Actions menu (owner only, not self, not owner role)
            if (isOwner && !isSelf && user.role != 'Owner') ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppTheme.onSurfaceMuted,
                ),
                color: AppTheme.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.outline),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_horiz_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Change Role',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          user.isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: user.isActive
                              ? AppTheme.warning
                              : AppTheme.secondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          user.isActive ? 'Disable Access' : 'Enable Access',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_remove_rounded,
                          size: 16,
                          color: AppTheme.error,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Remove',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'role') onChangeRole();
                  if (value == 'toggle') onToggleStatus();
                  if (value == 'remove') onRemove();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
