import './supabase_service.dart';

/// Central permission service for role-based access control.
/// All permission checks must go through this service to ensure
/// logic-level enforcement (not just visual).
class PermissionService {
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();
  PermissionService._();

  String _currentRole = 'Staff';
  String _currentUserId = '';
  bool _isActive = true;
  String _currentStoreId = '';

  void setUser({
    required String role,
    required String userId,
    required bool isActive,
    String storeId = '',
  }) {
    _currentRole = role;
    _currentUserId = userId;
    _isActive = isActive;
    _currentStoreId = storeId;
  }

  String get currentRole => _currentRole;
  String get currentUserId => _currentUserId;
  bool get isActive => _isActive;

  /// Re-fetches the current user's active status from Supabase.
  /// Call this before sensitive operations to catch mid-session disables.
  Future<bool> refreshActiveStatus() async {
    if (_currentUserId.isEmpty || _currentStoreId.isEmpty) return _isActive;
    try {
      final client = SupabaseService.instance.client;
      final resp = await client
          .from('store_members')
          .select('is_active')
          .eq('user_id', _currentUserId)
          .eq('store_id', _currentStoreId)
          .maybeSingle();

      if (resp != null) {
        _isActive = resp['is_active'] as bool? ?? false;
      }
    } catch (_) {
      // If check fails, keep current state — don't lock out on network error
    }
    return _isActive;
  }

  /// Returns false if user is disabled — blocks ALL actions
  bool get canPerformAnyAction => _isActive;

  // ─── Stock Actions ────────────────────────────────────────────────────────
  bool get canStockIn =>
      _isActive &&
      (_currentRole == 'Staff' ||
          _currentRole == 'Manager' ||
          _currentRole == 'Owner');
  bool get canStockOut =>
      _isActive &&
      (_currentRole == 'Staff' ||
          _currentRole == 'Manager' ||
          _currentRole == 'Owner');

  // ─── Item Management ──────────────────────────────────────────────────────
  bool get canCreateItem =>
      _isActive && (_currentRole == 'Manager' || _currentRole == 'Owner');
  bool get canEditItem =>
      _isActive && (_currentRole == 'Manager' || _currentRole == 'Owner');
  bool get canDeleteItem => _isActive && _currentRole == 'Owner';

  // ─── Category Management ──────────────────────────────────────────────────
  bool get canCreateCategory =>
      _isActive && (_currentRole == 'Manager' || _currentRole == 'Owner');
  bool get canEditCategory =>
      _isActive && (_currentRole == 'Manager' || _currentRole == 'Owner');
  bool get canDeleteCategory => _isActive && _currentRole == 'Owner';

  // ─── User Management ──────────────────────────────────────────────────────
  bool get canViewUsers => _isActive && _currentRole == 'Owner';
  bool get canAddUser => _isActive && _currentRole == 'Owner';
  bool get canEditUserRole => _isActive && _currentRole == 'Owner';
  bool get canDisableUser => _isActive && _currentRole == 'Owner';
  bool get canRemoveUser => _isActive && _currentRole == 'Owner';

  /// Checks if current user can change the role of a target user.
  /// Owner role cannot be changed.
  bool canChangeRoleOf(String targetRole) {
    if (!canEditUserRole) return false;
    if (targetRole == 'Owner') return false;
    return true;
  }

  /// Returns a human-readable denial reason for a given action.
  String denialReason(String action) {
    if (!_isActive) return 'Your account has been disabled. Contact the owner.';
    switch (_currentRole) {
      case 'Staff':
        return 'Staff can only perform stock in/out. Contact your manager.';
      case 'Manager':
        return 'Managers cannot $action. Contact the owner.';
      default:
        return 'You do not have permission to $action.';
    }
  }

  // ─── Activity Log ─────────────────────────────────────────────────────────
  /// Owner: all logs, Manager: stock-only logs, Staff: no access
  bool get canViewActivityLog =>
      _isActive && (_currentRole == 'Owner' || _currentRole == 'Manager');

  bool get canViewAllLogs => _isActive && _currentRole == 'Owner';
}
