import 'package:supabase_flutter/supabase_flutter.dart';

import './supabase_service.dart';

/// Action types for activity logging
class ActivityActionType {
  static const String stockIn = 'stock_in';
  static const String stockOut = 'stock_out';
  static const String itemCreated = 'item_created';
  static const String itemEdited = 'item_edited';
  static const String itemDeleted = 'item_deleted';
  static const String userAdded = 'user_added';
  static const String userRemoved = 'user_removed';
  static const String roleChanged = 'role_changed';
  static const String userEnabled = 'user_enabled';
  static const String userDisabled = 'user_disabled';
  static const String bulkImport = 'bulk_import';
  static const String categoryCreated = 'category_created';
  static const String categoryDeleted = 'category_deleted';

  static bool isStockAction(String type) => type == stockIn || type == stockOut;
}

/// A single activity log entry
class ActivityLogEntry {
  final String id;
  final String storeId;
  final String userId;
  final String userName;
  final String userRole;
  final String actionType;
  final String? itemId;
  final String? itemName;
  // quantity stored as double to preserve decimal values (DB column is NUMERIC)
  final double? quantity;
  final String? unit;
  final String? details;
  final DateTime createdAt;

  ActivityLogEntry({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.actionType,
    this.itemId,
    this.itemName,
    this.quantity,
    this.unit,
    this.details,
    required this.createdAt,
  });

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) {
    // quantity may be int or double from DB
    final rawQty = map['quantity'];
    double? qty;
    if (rawQty is int) {
      qty = rawQty.toDouble();
    } else if (rawQty is double) {
      qty = rawQty;
    } else if (rawQty is String) {
      qty = double.tryParse(rawQty);
    }
    return ActivityLogEntry(
      id: map['id'] as String? ?? '',
      storeId: map['store_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? 'Unknown',
      userRole: map['user_role'] as String? ?? 'Staff',
      actionType: map['action_type'] as String? ?? '',
      itemId: map['item_id'] as String?,
      itemName: map['item_name'] as String?,
      quantity: qty,
      unit: map['unit'] as String?,
      details: map['details'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'store_id': storeId,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'action_type': actionType,
      if (itemId != null) 'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (details != null) 'details': details,
    };
  }

  String get humanReadable {
    final time = _formatTime(createdAt);
    final qtyStr = quantity != null
        ? (quantity! == quantity!.truncateToDouble()
              ? quantity!.toInt().toString()
              : quantity!.toStringAsFixed(2))
        : '0';
    switch (actionType) {
      case ActivityActionType.stockIn:
        return '$userName added $qtyStr ${unit ?? 'units'} to ${itemName ?? 'item'} at $time';
      case ActivityActionType.stockOut:
        return '$userName removed $qtyStr ${unit ?? 'units'} from ${itemName ?? 'item'} at $time';
      case ActivityActionType.itemCreated:
        return '$userName created item "${itemName ?? 'item'}" at $time';
      case ActivityActionType.itemEdited:
        return '$userName edited item "${itemName ?? 'item'}" at $time';
      case ActivityActionType.itemDeleted:
        return '$userName deleted item "${itemName ?? 'item'}" at $time';
      case ActivityActionType.userAdded:
        return '$userName added ${details ?? 'a new user'} to the team at $time';
      case ActivityActionType.userRemoved:
        return '$userName removed ${details ?? 'a user'} from the team at $time';
      case ActivityActionType.roleChanged:
        return '$userName changed role: ${details ?? ''} at $time';
      case ActivityActionType.userEnabled:
        return '$userName enabled account: ${details ?? ''} at $time';
      case ActivityActionType.userDisabled:
        return '$userName disabled account: ${details ?? ''} at $time';
      case ActivityActionType.bulkImport:
        return '$userName bulk imported $qtyStr items at $time';
      case ActivityActionType.categoryCreated:
        return '$userName created category "${details ?? ''}" at $time';
      case ActivityActionType.categoryDeleted:
        return '$userName deleted category "${details ?? ''}" at $time';
      default:
        return '$userName performed $actionType at $time';
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

/// Result of a paginated fetch
class PaginatedLogsResult {
  final List<ActivityLogEntry> logs;
  final bool hasMore;

  const PaginatedLogsResult({required this.logs, required this.hasMore});
}

/// Service for logging and fetching activity logs (store-scoped)
class ActivityLogService {
  static ActivityLogService? _instance;
  static ActivityLogService get instance =>
      _instance ??= ActivityLogService._();
  ActivityLogService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  static const int _pageSize = 30;

  /// Log an activity action — requires storeId for data isolation.
  /// userId is validated against the current authenticated user to prevent spoofing.
  Future<void> log({
    required String storeId,
    required String userId,
    required String userName,
    required String userRole,
    required String actionType,
    String? itemId,
    String? itemName,
    double? quantity,
    String? unit,
    String? details,
  }) async {
    if (storeId.isEmpty) return;

    // Security: verify the userId matches the authenticated session user
    // This prevents a client from logging actions as another user
    final authUserId = _client.auth.currentUser?.id;
    if (authUserId == null) return; // Not authenticated — refuse to log
    // Use the authenticated user ID, not the passed userId (prevents spoofing)
    final safeUserId = authUserId;

    // Validate actionType is a known type to prevent injection of arbitrary strings
    const knownTypes = {
      ActivityActionType.stockIn,
      ActivityActionType.stockOut,
      ActivityActionType.itemCreated,
      ActivityActionType.itemEdited,
      ActivityActionType.itemDeleted,
      ActivityActionType.userAdded,
      ActivityActionType.userRemoved,
      ActivityActionType.roleChanged,
      ActivityActionType.userEnabled,
      ActivityActionType.userDisabled,
      ActivityActionType.bulkImport,
      ActivityActionType.categoryCreated,
      ActivityActionType.categoryDeleted,
    };
    if (!knownTypes.contains(actionType)) return;

    // Validate quantity is non-negative if provided
    final safeQuantity = quantity?.abs();

    final entry = ActivityLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      storeId: storeId,
      userId: safeUserId,
      userName: userName.isNotEmpty ? userName : 'Unknown',
      userRole: userRole,
      actionType: actionType,
      itemId: itemId,
      itemName: itemName,
      quantity: safeQuantity,
      unit: unit,
      details: details,
      createdAt: DateTime.now(),
    );

    try {
      await _client.from('activity_logs').insert(entry.toMap());
    } catch (_) {
      // Silently fail — logging should never crash the app
    }
  }

  /// Fetch a single page of logs with server-side filtering, scoped to storeId.
  Future<PaginatedLogsResult> fetchLogsPage({
    required String storeId,
    String? filterUser,
    String? filterItem,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? actionTypes,
    int page = 0,
    int pageSize = _pageSize,
  }) async {
    if (storeId.isEmpty) {
      return const PaginatedLogsResult(logs: [], hasMore: false);
    }

    try {
      var query = _client
          .from('activity_logs')
          .select()
          .eq('store_id', storeId);

      if (filterUser != null && filterUser.isNotEmpty) {
        query = query.ilike('user_name', '%$filterUser%');
      }
      if (filterItem != null && filterItem.isNotEmpty) {
        query = query.ilike('item_name', '%$filterItem%');
      }
      if (fromDate != null) {
        query = query.gte('created_at', fromDate.toIso8601String());
      }
      if (toDate != null) {
        final endOfDay = toDate.add(const Duration(days: 1));
        query = query.lt('created_at', endOfDay.toIso8601String());
      }
      if (actionTypes != null && actionTypes.isNotEmpty) {
        query = query.inFilter('action_type', actionTypes);
      }

      final from = page * pageSize;
      final to = from + pageSize;
      final response =
          await query.order('created_at', ascending: false).range(from, to)
              as List;

      final hasMore = response.length > pageSize;
      final pageItems = hasMore ? response.sublist(0, pageSize) : response;

      final entries = pageItems
          .map((row) => ActivityLogEntry.fromMap(row as Map<String, dynamic>))
          .toList();

      return PaginatedLogsResult(logs: entries, hasMore: hasMore);
    } catch (_) {
      return const PaginatedLogsResult(logs: [], hasMore: false);
    }
  }

  /// Get recent logs for dashboard (store-scoped)
  Future<List<ActivityLogEntry>> fetchRecentLogs({
    required String storeId,
    int count = 5,
  }) async {
    final result = await fetchLogsPage(
      storeId: storeId,
      page: 0,
      pageSize: count,
    );
    return result.logs;
  }
}
