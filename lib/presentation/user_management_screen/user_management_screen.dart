import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../services/activity_log_service.dart';
import '../../services/permission_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';
import './widgets/change_role_sheet_widget.dart';
import './widgets/invite_user_sheet_widget.dart';
import './widgets/user_list_item_widget.dart';

/// AppUser backed by StoreMember
class AppUser {
  final String id; // store_member id
  final String userId; // user_profiles id
  final String name;
  final String email;
  final String contact;
  String role;
  final DateTime lastActive;
  bool isActive;

  AppUser({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.contact = '',
    required this.role,
    required this.lastActive,
    required this.isActive,
  });

  factory AppUser.fromMember(StoreMember member) {
    return AppUser(
      id: member.id,
      userId: member.userId,
      name: member.userName ?? member.userEmail?.split('@').first ?? 'Unknown',
      email: member.userEmail ?? '',
      role: member.role,
      lastActive: member.createdAt,
      isActive: member.isActive,
    );
  }
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _userRole = 'Owner';
  String _userName = '';
  String _userId = '';
  String _storeId = '';
  String _storeName = '';
  bool _isLoading = true;
  List<AppUser> _users = [];

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
      _userName = args['userName'] as String? ?? 'Owner';
      _userId = args['userId'] as String? ?? '';
      _storeId = newStoreId;
      _storeName =
          args['storeName'] as String? ??
          StoreService.instance.currentStore?.name ??
          '';
      final isActive = args['isActive'] as bool? ?? true;
      PermissionService.instance.setUser(
        role: _userRole,
        userId: _userId,
        isActive: isActive,
        storeId: _storeId,
      );

      if (_storeId.isNotEmpty && (storeChanged || roleChanged || _isLoading)) {
        _loadMembers();
      }
    }
  }

  Future<void> _loadMembers() async {
    if (_storeId.isEmpty) return;
    setState(() => _isLoading = true);
    final members = await StoreService.instance.fetchStoreMembers(_storeId);
    if (mounted) {
      setState(() {
        _users = members.map(AppUser.fromMember).toList();
        _isLoading = false;
      });
    }
  }

  bool get _canManage =>
      PermissionService.instance.canViewUsers || _userRole == 'Owner';

  void _showChangeRoleSheet(AppUser user) {
    if (_userRole != 'Owner') {
      _showDenied('manage users');
      return;
    }
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
              ),
            );
          }
        },
      ),
    );
  }

  void _showAddStaffSheet() {
    if (_userRole != 'Owner') {
      _showDenied('add staff');
      return;
    }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$email invited as $role')));
        },
      ),
    );
  }

  void _toggleUserStatus(AppUser user) {
    if (_userRole != 'Owner') {
      _showDenied('enable/disable users');
      return;
    }
    if (user.role == 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner account cannot be disabled.')),
      );
      return;
    }
    final action = user.isActive ? 'disable' : 'enable';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Account'),
        content: Text(
          user.isActive
              ? 'Disable ${user.name}? They will not be able to access this store.'
              : 'Enable ${user.name}? They will regain access to this store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                      '${user.name} has been ${user.isActive ? 'enabled' : 'disabled'}',
                    ),
                  ),
                );
              }
            },
            child: Text(
              action[0].toUpperCase() + action.substring(1),
              style: TextStyle(
                color: user.isActive ? AppTheme.error : AppTheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _removeUser(AppUser user) {
    if (_userRole != 'Owner') {
      _showDenied('remove users');
      return;
    }
    if (user.role == 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner account cannot be removed.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Text(
          'Remove ${user.name} from the team? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await StoreService.instance.removeMember(
                user.id,
                _storeId,
              );
              if (success && mounted) {
                setState(() => _users.remove(user));
                ActivityLogService.instance.log(
                  storeId: _storeId,
                  userId: _userId,
                  userName: _userName,
                  userRole: _userRole,
                  actionType: ActivityActionType.userRemoved,
                  details: '${user.name} (${user.role})',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${user.name} has been removed')),
                );
              }
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDenied(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(PermissionService.instance.denialReason(action)),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    const navIndex = 3;

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: AppNavigation(
        currentIndex: navIndex,
        userRole: _userRole,
        userName: _userName,
        userId: _userId,
        isActive: PermissionService.instance.isActive,
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
                  isActive: PermissionService.instance.isActive,
                  storeId: _storeId,
                  storeName: _storeName,
                ),
                Expanded(child: _buildBody()),
              ],
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _userRole != 'Owner'
                ? _buildPermissionDenied()
                : _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _users.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.people_outline_rounded,
                    title: 'No team members yet',
                    subtitle: 'Invite collaborators to this store.',
                    actionLabel: 'Invite Member',
                    onAction: _showAddStaffSheet,
                  )
                : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team',
                  style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _userRole == 'Owner'
                      ? '${_storeName.isNotEmpty ? "$_storeName · " : ""}${_users.length} members'
                      : 'Owner access required',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_userRole == 'Owner')
            ElevatedButton.icon(
              onPressed: _showAddStaffSheet,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Invite'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Owner Access Only',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'User management is restricted to the Owner role.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    final roleOrder = {'Owner': 0, 'Manager': 1, 'Staff': 2};
    final sorted = [..._users]
      ..sort(
        (a, b) => (roleOrder[a.role] ?? 3).compareTo(roleOrder[b.role] ?? 3),
      );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 240 + (i * 50).clamp(0, 350)),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: UserListItemWidget(
              user: sorted[i],
              currentUserRole: _userRole,
              onTap: () => _showChangeRoleSheet(sorted[i]),
              onToggleStatus: () => _toggleUserStatus(sorted[i]),
              onRemove: () => _removeUser(sorted[i]),
            ),
          ),
        );
      },
    );
  }
}
