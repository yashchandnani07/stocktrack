import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_service.dart';
import './inventory_service.dart';
import './activity_log_service.dart';

/// A single item in a stock session
class StockSessionItem {
  final String itemId;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;

  const StockSessionItem({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap(String sessionId) => {
    'session_id': sessionId,
    'item_id': itemId,
    'item_name': itemName,
    'category': category,
    'quantity': quantity,
    'unit': unit,
  };

  factory StockSessionItem.fromMap(Map<String, dynamic> m) => StockSessionItem(
    itemId: m['item_id'] as String? ?? '',
    itemName: m['item_name'] as String? ?? '',
    category: m['category'] as String? ?? 'General',
    quantity: (m['quantity'] as num?)?.toDouble() ?? 0.0,
    unit: m['unit'] as String? ?? 'pcs',
  );
}

/// A stock session record
class StockSession {
  final String id;
  final String storeId;
  final String sessionType; // 'IN' or 'OUT'
  final String performedById;
  final String performedByName;
  final String performedByRole;
  final int totalItems;
  final String? notes;
  final DateTime createdAt;
  final List<StockSessionItem> items;

  const StockSession({
    required this.id,
    required this.storeId,
    required this.sessionType,
    required this.performedById,
    required this.performedByName,
    required this.performedByRole,
    required this.totalItems,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  factory StockSession.fromMap(
    Map<String, dynamic> m, {
    List<StockSessionItem> items = const [],
  }) {
    return StockSession(
      id: m['id'] as String? ?? '',
      storeId: m['store_id'] as String? ?? '',
      sessionType: m['session_type'] as String? ?? 'IN',
      performedById: m['performed_by_id'] as String? ?? '',
      performedByName: m['performed_by_name'] as String? ?? '',
      performedByRole: m['performed_by_role'] as String? ?? 'Staff',
      totalItems: m['total_items'] as int? ?? 0,
      notes: m['notes'] as String?,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
      items: items,
    );
  }
}

/// Result of a session submission
class SessionResult {
  final bool success;
  final StockSession? session;
  final String? error;
  final List<String> failedItems;

  const SessionResult({
    required this.success,
    this.session,
    this.error,
    this.failedItems = const [],
  });
}

/// Service for bulk stock session operations
class StockSessionService {
  static StockSessionService? _instance;
  static StockSessionService get instance =>
      _instance ??= StockSessionService._();
  StockSessionService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// Submit a stock session: update all items, log activities, create session record
  Future<SessionResult> submitSession({
    required String storeId,
    required String sessionType, // 'IN' or 'OUT'
    required String userId,
    required String userName,
    required String userRole,
    required String storeName,
    required List<StockSessionItem> items,
    String? notes,
  }) async {
    if (storeId.isEmpty || items.isEmpty) {
      return const SessionResult(
        success: false,
        error: 'Store or items missing',
      );
    }

    final failedItems = <String>[];

    // 1. Apply stock deltas for each item
    for (final item in items) {
      final delta = sessionType == 'IN' ? item.quantity : -item.quantity;
      final result = await InventoryService.instance.applyStockDelta(
        itemId: item.itemId,
        storeId: storeId,
        delta: delta,
        updatedBy: userName,
      );
      if (!result.success) {
        failedItems.add(item.itemName);
      }
    }

    // 2. Log activity for each item
    for (final item in items) {
      if (failedItems.contains(item.itemName)) continue;
      await ActivityLogService.instance.log(
        storeId: storeId,
        userId: userId,
        userName: userName,
        userRole: userRole,
        actionType: sessionType == 'IN'
            ? ActivityActionType.stockIn
            : ActivityActionType.stockOut,
        itemId: item.itemId,
        itemName: item.itemName,
        quantity: item.quantity, // preserve decimal — do NOT round
        unit: item.unit,
        details: 'Bulk session',
      );
    }

    // 3. Create session record
    try {
      final successItems = items
          .where((i) => !failedItems.contains(i.itemName))
          .toList();

      final sessionData = await _client
          .from('stock_sessions')
          .insert({
            'store_id': storeId,
            'session_type': sessionType,
            'performed_by_id': userId,
            'performed_by_name': userName,
            'performed_by_role': userRole,
            'total_items': successItems.length,
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          })
          .select()
          .single();

      final session = StockSession.fromMap(sessionData);

      // 4. Insert session items
      if (successItems.isNotEmpty) {
        await _client
            .from('stock_session_items')
            .insert(successItems.map((i) => i.toMap(session.id)).toList());
      }

      final fullSession = StockSession(
        id: session.id,
        storeId: session.storeId,
        sessionType: session.sessionType,
        performedById: session.performedById,
        performedByName: session.performedByName,
        performedByRole: session.performedByRole,
        totalItems: session.totalItems,
        notes: session.notes,
        createdAt: session.createdAt,
        items: successItems,
      );

      return SessionResult(
        success: true,
        session: fullSession,
        failedItems: failedItems,
      );
    } catch (e) {
      return SessionResult(
        success: false,
        error: 'Failed to save session: $e',
        failedItems: failedItems,
      );
    }
  }

  /// Fetch past sessions for a store (paginated)
  Future<List<StockSession>> fetchSessions({
    required String storeId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('stock_sessions')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((m) => StockSession.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch a single session with its items
  Future<StockSession?> fetchSessionWithItems(String sessionId) async {
    try {
      final sessionData = await _client
          .from('stock_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      final itemsData = await _client
          .from('stock_session_items')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      final items = (itemsData as List)
          .map((m) => StockSessionItem.fromMap(m as Map<String, dynamic>))
          .toList();

      return StockSession.fromMap(sessionData, items: items);
    } catch (e) {
      return null;
    }
  }
}
