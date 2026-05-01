import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_service.dart';

/// Represents a store (shop) owned by a user
class StoreModel {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  StoreModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerId: map['owner_id'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Represents a store member (collaborator)
class StoreMember {
  final String id;
  final String storeId;
  final String userId;
  final String role;
  bool isActive;
  final String? invitedBy;
  final DateTime createdAt;

  // Joined from user_profiles
  String? userName;
  String? userEmail;

  StoreMember({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.role,
    required this.isActive,
    this.invitedBy,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory StoreMember.fromMap(Map<String, dynamic> map) {
    final profile = map['user_profiles'] as Map<String, dynamic>?;
    return StoreMember(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String,
      isActive: map['is_active'] as bool? ?? true,
      invitedBy: map['invited_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      userName: profile?['full_name'] as String?,
      userEmail: profile?['email'] as String?,
    );
  }
}

/// Central service for store management and selection
class StoreService {
  static StoreService? _instance;
  static StoreService get instance => _instance ??= StoreService._();
  StoreService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// Expose client for direct store updates from other screens
  SupabaseClient get client => SupabaseService.instance.client;

  // Currently selected store
  StoreModel? _currentStore;
  StoreModel? get currentStore => _currentStore;

  // Current user's role in the selected store
  String _currentRole = 'Staff';
  String get currentRole => _currentRole;

  void setCurrentStore(StoreModel store, String role) {
    _currentStore = store;
    _currentRole = role;
    debugPrint(
      '[StoreService] setCurrentStore — store_id: ${store.id} '
      'name: "${store.name}" role: $role',
    );
  }

  void clearCurrentStore() {
    _currentStore = null;
    _currentRole = 'Staff';
  }

  /// Fetch all stores accessible to the current user (owned + member).
  /// The explicit join through store_members ensures only accessible stores
  /// are returned even if RLS is misconfigured.
  Future<List<StoreModel>> fetchMyStores() async {
    final userId = _client.auth.currentUser?.id;
    debugPrint('[StoreService] fetchMyStores — user_id: $userId');
    if (userId == null) {
      debugPrint(
        '[StoreService] fetchMyStores — no authenticated user, returning empty list',
      );
      return [];
    }

    try {
      // Fetch stores where user is owner
      final ownedResp = await _client
          .from('stores')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: true);

      // Fetch stores where user is an active member
      final memberResp = await _client
          .from('store_members')
          .select('store_id, stores(*)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      final Set<String> seen = {};
      final List<StoreModel> stores = [];

      for (final row in (ownedResp as List)) {
        final store = StoreModel.fromMap(row as Map<String, dynamic>);
        if (seen.add(store.id)) stores.add(store);
      }

      for (final row in (memberResp as List)) {
        final storeData = row['stores'] as Map<String, dynamic>?;
        if (storeData != null) {
          final store = StoreModel.fromMap(storeData);
          if (seen.add(store.id)) stores.add(store);
        }
      }

      // Always sort by created_at ascending for deterministic ordering
      // across web and mobile — ensures both platforms pick the same
      // "first" store when auto-selecting
      stores.sort((a, b) {
        final cmp = a.createdAt.compareTo(b.createdAt);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });
      debugPrint(
        '[StoreService] fetchMyStores — found ${stores.length} store(s): '
        '${stores.map((s) => '${s.name}(${s.id})').join(', ')}',
      );
      return stores;
    } catch (e) {
      debugPrint('[StoreService] fetchMyStores — error: $e');
      return [];
    }
  }

  /// Create a new store for the current user
  Future<StoreModel?> createStore(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('stores')
          .insert({'name': name.trim(), 'owner_id': userId})
          .select()
          .single();

      return StoreModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Get the current user's role in a specific store
  Future<String> getRoleInStore(String storeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'Staff';

    try {
      // Check if owner
      final storeResp = await _client
          .from('stores')
          .select('owner_id')
          .eq('id', storeId)
          .maybeSingle();

      if (storeResp != null && storeResp['owner_id'] == userId) {
        return 'Owner';
      }

      // Check member role
      final memberResp = await _client
          .from('store_members')
          .select('role')
          .eq('store_id', storeId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (memberResp != null) {
        return memberResp['role'] as String? ?? 'Staff';
      }

      return 'Staff';
    } catch (e) {
      return 'Staff';
    }
  }

  /// Fetch all members of a store
  Future<List<StoreMember>> fetchStoreMembers(String storeId) async {
    try {
      final response = await _client
          .from('store_members')
          .select('*, user_profiles(full_name, email)')
          .eq('store_id', storeId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((m) => StoreMember.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Invite a user to a store by email
  Future<String?> inviteMember({
    required String storeId,
    required String email,
    required String role,
  }) async {
    final inviterId = _client.auth.currentUser?.id;
    if (inviterId == null) return 'Not authenticated';

    try {
      // Look up user by email
      final profileResp = await _client
          .from('user_profiles')
          .select('id, full_name')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (profileResp == null) {
        return 'No user found with that email. They must sign up first.';
      }

      final targetUserId = profileResp['id'] as String;

      // Check not already a member
      final existing = await _client
          .from('store_members')
          .select('id')
          .eq('store_id', storeId)
          .eq('user_id', targetUserId)
          .maybeSingle();

      if (existing != null) {
        return 'This user is already a member of this store.';
      }

      await _client.from('store_members').insert({
        'store_id': storeId,
        'user_id': targetUserId,
        'role': role,
        'is_active': true,
        'invited_by': inviterId,
      });

      return null; // success
    } catch (e) {
      return 'Failed to invite member: $e';
    }
  }

  /// Update a member's role — verifies caller is the store owner
  Future<bool> updateMemberRole({
    required String memberId,
    required String newRole,
    required String storeId,
  }) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null) return false;

    // Verify the caller is the store owner before allowing role change
    final isOwner = await _isCallerStoreOwner(storeId);
    if (!isOwner) return false;

    // Prevent changing the Owner role
    if (newRole == 'Owner') return false;

    try {
      await _client
          .from('store_members')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', memberId)
          .eq('store_id', storeId); // ← scope to store
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle a member's active status — verifies caller is the store owner
  Future<bool> toggleMemberStatus({
    required String memberId,
    required bool isActive,
    required String storeId,
  }) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null) return false;

    final isOwner = await _isCallerStoreOwner(storeId);
    if (!isOwner) return false;

    try {
      await _client
          .from('store_members')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', memberId)
          .eq('store_id', storeId); // ← scope to store
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a member from a store — verifies caller is the store owner
  Future<bool> removeMember(String memberId, String storeId) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null) return false;

    final isOwner = await _isCallerStoreOwner(storeId);
    if (!isOwner) return false;

    try {
      await _client
          .from('store_members')
          .delete()
          .eq('id', memberId)
          .eq('store_id', storeId); // ← scope to store
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Internal helper: verify the current user is the owner of the given store
  Future<bool> _isCallerStoreOwner(String storeId) async {
    final callerId = _client.auth.currentUser?.id;
    if (callerId == null || storeId.isEmpty) return false;
    try {
      final resp = await _client
          .from('stores')
          .select('owner_id')
          .eq('id', storeId)
          .maybeSingle();
      return resp != null && resp['owner_id'] == callerId;
    } catch (_) {
      return false;
    }
  }
}
