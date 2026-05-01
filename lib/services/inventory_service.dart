import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './store_service.dart';
import './supabase_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const int kMaxItemNameLength = 120;
const double kMaxQuantity = 999999.0;
const int kMaxThreshold = 999999;

/// Rounds a quantity to at most 2 decimal places to avoid floating-point drift.
double _roundQty(double v) => (v * 100).roundToDouble() / 100;

/// Formats a quantity for display: whole numbers show without decimals,
/// fractional values show up to 2 decimal places.
String formatQuantity(double qty) {
  final rounded = _roundQty(qty);
  if (rounded == rounded.truncateToDouble()) {
    return rounded.toInt().toString();
  }
  // Remove trailing zero (e.g. 88.90 → "88.9")
  final s = rounded.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// Inventory item model (Supabase-backed)
class InventoryItem {
  final String id;
  final String storeId;
  final String name;
  final String category;
  double quantity;
  final int lowStockThreshold;
  final String unit;
  final String? barcode;
  DateTime lastUpdated;
  String updatedBy;

  InventoryItem({
    required this.id,
    required this.storeId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.lowStockThreshold,
    required this.unit,
    this.barcode,
    required this.lastUpdated,
    required this.updatedBy,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    // quantity may come back as int or double from Supabase
    final rawQty = map['quantity'];
    final qty = rawQty is int
        ? rawQty.toDouble()
        : (rawQty as num?)?.toDouble() ?? 0.0;
    return InventoryItem(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'General',
      quantity: _roundQty(qty),
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
      unit: map['unit'] as String? ?? 'pcs',
      barcode: map['barcode'] as String?,
      lastUpdated: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      updatedBy: map['updated_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'store_id': storeId,
      'name': name,
      'category': category,
      'quantity': _roundQty(quantity.clamp(-kMaxQuantity, kMaxQuantity)),
      'low_stock_threshold': lowStockThreshold.clamp(0, kMaxThreshold),
      'unit': unit,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      'updated_by': updatedBy,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'category': category,
      'quantity': _roundQty(quantity.clamp(-kMaxQuantity, kMaxQuantity)),
      'low_stock_threshold': lowStockThreshold.clamp(0, kMaxThreshold),
      'unit': unit,
      'barcode': barcode,
      'updated_by': updatedBy,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  InventoryItem copyWith({
    double? quantity,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return InventoryItem(
      id: id,
      storeId: storeId,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold,
      unit: unit,
      barcode: barcode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

/// Category model (Supabase-backed)
class CategoryModel {
  final String id;
  final String storeId;
  final String name;
  final Color color;
  final IconData icon;
  int itemCount;

  CategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.color,
    required this.icon,
    required this.itemCount,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    // color_value is stored as bigint in DB — may come back as int or String
    final rawColor = map['color_value'];
    int colorInt;
    if (rawColor is int) {
      colorInt = rawColor;
    } else if (rawColor is String) {
      colorInt = int.tryParse(rawColor) ?? 0xFF3B5BDB;
    } else {
      colorInt = 0xFF3B5BDB;
    }
    return CategoryModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      name: map['name'] as String,
      color: Color(colorInt),
      icon: IconData(
        map['icon_code'] as int? ?? Icons.category_rounded.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      itemCount: map['item_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'store_id': storeId,
      'name': name,
      'color_value': color.value,
      'icon_code': icon.codePoint,
    };
  }
}

/// Result of an atomic stock update
class StockUpdateResult {
  final bool success;
  final double? newQuantity;
  final String? error;

  const StockUpdateResult({
    required this.success,
    this.newQuantity,
    this.error,
  });
}

/// Service for inventory items and categories (store-scoped)
class InventoryService {
  static InventoryService? _instance;
  static InventoryService get instance => _instance ??= InventoryService._();
  InventoryService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// Stores the last error message from createItem / createCategory for callers
  /// that need the exact database error (e.g. CSV import error reporting).
  String? lastError;

  // ─── Items ────────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> fetchItems(String storeId) async {
    final user = Supabase.instance.client.auth.currentUser;
    final activeStore = StoreService.instance.currentStore;
    debugPrint(
      '[InventoryService] fetchItems — '
      'platform: ${kIsWeb ? "web" : "mobile"} '
      'requested_store_id: "$storeId" '
      'active_store_id: "${activeStore?.id ?? "null"}" '
      'active_store_name: "${activeStore?.name ?? ""}" '
      'user_id: ${user?.id ?? "null"} '
      'email: ${user?.email ?? "null"}',
    );
    if (storeId.isEmpty) {
      debugPrint(
        '[InventoryService] fetchItems — ABORT: storeId is EMPTY. '
        'Caller MUST resolve a store before reading items.',
      );
      return [];
    }
    if (activeStore != null && activeStore.id != storeId) {
      // Hard signal that something is calling fetchItems with a stale id
      // while StoreService points elsewhere. We still honor the explicit
      // [storeId] argument (it's the contract) but log loudly so the
      // mismatch is debuggable in production logs.
      debugPrint(
        '[InventoryService] fetchItems — WARNING: requested_store_id "$storeId" '
        '!= StoreService.currentStore.id "${activeStore.id}" — '
        'this is a likely source of "items not visible" reports.',
      );
    }
    try {
      final response = await _client
          .from('inventory_items')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((m) => InventoryItem.fromMap(m as Map<String, dynamic>))
          .toList();
      debugPrint(
        '[InventoryService] fetchItems — returned ${items.length} item(s) '
        'for store_id: "$storeId" (user_id: ${user?.id ?? "null"})',
      );
      return items;
    } catch (e) {
      debugPrint('[InventoryService] fetchItems — error: $e');
      return [];
    }
  }

  Future<InventoryItem?> createItem(InventoryItem item) async {
    final user = Supabase.instance.client.auth.currentUser;
    final activeStore = StoreService.instance.currentStore;
    debugPrint(
      '[InventoryService] createItem — '
      'platform: ${kIsWeb ? "web" : "mobile"} '
      'requested_store_id: "${item.storeId}" '
      'active_store_id: "${activeStore?.id ?? "null"}" '
      'name: "${item.name}" '
      'user_id: ${user?.id ?? "null"}',
    );
    // Validate storeId is present — prevents orphan inserts
    if (item.storeId.isEmpty) {
      lastError =
          'Cannot create item without a store. Please re-select your store.';
      return null;
    }
    if (activeStore != null && activeStore.id != item.storeId) {
      // Refuse to write to a store that doesn't match the active context.
      // This is what prevents the "created on web, invisible on mobile"
      // class of bugs at write-time.
      debugPrint(
        '[InventoryService] createItem — REJECT: item.storeId '
        '"${item.storeId}" != active store "${activeStore.id}". '
        'Refusing to create item under a stale store context.',
      );
      lastError =
          'Store context mismatch. Please re-select your store and try again.';
      return null;
    }
    // Validate name
    final trimmedName = item.name.trim();
    if (trimmedName.isEmpty || trimmedName.length > kMaxItemNameLength) {
      return null;
    }
    try {
      final response = await _client
          .from('inventory_items')
          .insert(item.toInsertMap())
          .select()
          .single();

      return InventoryItem.fromMap(response);
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  /// Update item metadata — MUST include store_id filter to prevent cross-store writes
  Future<InventoryItem?> updateItem(InventoryItem item) async {
    if (item.storeId.isEmpty || item.id.isEmpty) return null;
    final trimmedName = item.name.trim();
    if (trimmedName.isEmpty || trimmedName.length > kMaxItemNameLength) {
      return null;
    }
    try {
      final response = await _client
          .from('inventory_items')
          .update(item.toUpdateMap())
          .eq('id', item.id)
          .eq('store_id', item.storeId) // ← security: scope to store
          .select()
          .single();

      return InventoryItem.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Atomically apply a stock delta (positive = stock in, negative = stock out).
  /// Accepts double delta to support decimal quantities.
  Future<StockUpdateResult> applyStockDelta({
    required String itemId,
    required String storeId,
    required double delta, // positive for in, negative for out
    required String updatedBy,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final activeStore = StoreService.instance.currentStore;
    debugPrint(
      '[InventoryService] applyStockDelta — '
      'platform: ${kIsWeb ? "web" : "mobile"} '
      'item_id: "$itemId" '
      'requested_store_id: "$storeId" '
      'active_store_id: "${activeStore?.id ?? "null"}" '
      'delta: $delta updatedBy: "$updatedBy" '
      'user_id: ${user?.id ?? "null"}',
    );
    if (storeId.isEmpty || itemId.isEmpty) {
      debugPrint(
        '[InventoryService] applyStockDelta — REJECTED: '
        'storeId empty=${storeId.isEmpty} itemId empty=${itemId.isEmpty}',
      );
      return StockUpdateResult(
        success: false,
        error: storeId.isEmpty
            ? 'No store selected. Please re-select your store.'
            : 'Invalid item.',
      );
    }
    if (activeStore != null && activeStore.id != storeId) {
      // Caller passed a stale storeId while the singleton has moved on.
      // Refuse the write — if we let it through, the row would update
      // under one store while the user is viewing another.
      debugPrint(
        '[InventoryService] applyStockDelta — REJECTED: requested_store_id '
        '"$storeId" != active store "${activeStore.id}" — STORE CONTEXT '
        'MISMATCH. Refusing to write under a stale store context.',
      );
      return const StockUpdateResult(
        success: false,
        error:
            'Store context mismatch. Please refresh and re-select your store.',
      );
    }
    if (delta == 0) {
      return const StockUpdateResult(
        success: false,
        error: 'Quantity must be greater than 0',
      );
    }

    try {
      // Fetch current quantity with store_id scope (prevents cross-store access)
      // Use maybeSingle() instead of single() to avoid throwing when item not found
      final current = await _client
          .from('inventory_items')
          .select('quantity, store_id')
          .eq('id', itemId)
          .eq('store_id', storeId) // ← security: scope to store
          .maybeSingle();

      if (current == null) {
        // Item not found under this store_id — diagnose the mismatch
        debugPrint(
          '[InventoryService] applyStockDelta — item "$itemId" NOT FOUND '
          'under store_id "$storeId". Checking actual item store...',
        );
        try {
          final anyItem = await _client
              .from('inventory_items')
              .select('store_id')
              .eq('id', itemId)
              .maybeSingle();
          if (anyItem != null) {
            debugPrint(
              '[InventoryService] applyStockDelta — item "$itemId" actually '
              'belongs to store_id "${anyItem['store_id']}" — '
              'STORE CONTEXT MISMATCH! Active store: "$storeId"',
            );
          } else {
            debugPrint(
              '[InventoryService] applyStockDelta — item "$itemId" does not '
              'exist in any store',
            );
          }
        } catch (_) {}
        return const StockUpdateResult(
          success: false,
          error: 'Item not found in this store. Please refresh the inventory.',
        );
      }

      final rawCurrent = current['quantity'];
      final currentQty = rawCurrent is int
          ? rawCurrent.toDouble()
          : (rawCurrent as num?)?.toDouble() ?? 0.0;
      final newQty = _roundQty(currentQty + delta);

      // Prevent negative stock — stock out cannot exceed available quantity
      if (newQty < 0) {
        return StockUpdateResult(
          success: false,
          error: 'Insufficient stock. Available: ${formatQuantity(currentQty)}',
        );
      }

      // Enforce max cap
      if (newQty > kMaxQuantity) {
        return StockUpdateResult(
          success: false,
          error: 'Stock cannot exceed $kMaxQuantity',
        );
      }

      // Perform update with optimistic concurrency: only update if quantity
      // hasn't changed since we read it (prevents race conditions)
      final updated = await _client
          .from('inventory_items')
          .update({
            'quantity': newQty,
            'updated_by': updatedBy,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId)
          .eq('store_id', storeId) // ← security: scope to store
          .eq(
            'quantity',
            currentQty,
          ) // ← optimistic lock: only update if unchanged
          .select()
          .maybeSingle();

      if (updated == null) {
        // Another update happened concurrently — retry once with fresh data
        final retry = await _client
            .from('inventory_items')
            .select('quantity')
            .eq('id', itemId)
            .eq('store_id', storeId)
            .maybeSingle();

        if (retry == null) {
          return const StockUpdateResult(
            success: false,
            error:
                'Item not found in this store. Please refresh the inventory.',
          );
        }

        final rawRetry = retry['quantity'];
        final retryQty = rawRetry is int
            ? rawRetry.toDouble()
            : (rawRetry as num?)?.toDouble() ?? 0.0;
        final retryNewQty = _roundQty(retryQty + delta);

        // Re-check constraints with fresh quantity
        if (retryNewQty < 0) {
          return StockUpdateResult(
            success: false,
            error:
                'Insufficient stock after concurrent update. Available: ${formatQuantity(retryQty)}',
          );
        }
        if (retryNewQty > kMaxQuantity) {
          return StockUpdateResult(
            success: false,
            error: 'Stock cannot exceed $kMaxQuantity',
          );
        }

        // Use optimistic lock on retry too to prevent double-apply
        final retryUpdated = await _client
            .from('inventory_items')
            .update({
              'quantity': retryNewQty,
              'updated_by': updatedBy,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', itemId)
            .eq('store_id', storeId)
            .eq('quantity', retryQty) // ← optimistic lock on retry
            .select()
            .maybeSingle();

        if (retryUpdated == null) {
          return const StockUpdateResult(
            success: false,
            error: 'Concurrent update conflict. Please try again.',
          );
        }

        final rawNew = retryUpdated['quantity'];
        return StockUpdateResult(
          success: true,
          newQuantity: rawNew is int
              ? rawNew.toDouble()
              : (rawNew as num?)?.toDouble() ?? 0.0,
        );
      }

      final rawNew = updated['quantity'];
      return StockUpdateResult(
        success: true,
        newQuantity: rawNew is int
            ? rawNew.toDouble()
            : (rawNew as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('[InventoryService] applyStockDelta — exception: $e');
      return StockUpdateResult(success: false, error: 'Update failed: $e');
    }
  }

  /// Legacy direct quantity setter — kept for edit-item flow only.
  /// MUST include storeId to prevent cross-store writes.
  Future<bool> updateItemQuantity({
    required String itemId,
    required String storeId,
    required double newQuantity,
    required String updatedBy,
  }) async {
    if (storeId.isEmpty || itemId.isEmpty) return false;
    // Enforce bounds at service level
    final safeQty = _roundQty(newQuantity.clamp(-kMaxQuantity, kMaxQuantity));
    try {
      await _client
          .from('inventory_items')
          .update({
            'quantity': safeQty,
            'updated_by': updatedBy,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId)
          .eq('store_id', storeId); // ← security: scope to store
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete item — MUST include storeId to prevent cross-store deletes
  Future<bool> deleteItem(String itemId, String storeId) async {
    if (storeId.isEmpty || itemId.isEmpty) return false;
    try {
      await _client
          .from('inventory_items')
          .delete()
          .eq('id', itemId)
          .eq('store_id', storeId); // ← security: scope to store
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Categories ───────────────────────────────────────────────────────────

  Future<List<CategoryModel>> fetchCategories(String storeId) async {
    try {
      // Fetch categories and compute item_count from inventory_items
      final response = await _client
          .from('categories')
          .select()
          .eq('store_id', storeId)
          .order('name', ascending: true);

      final cats = (response as List)
          .map((m) => CategoryModel.fromMap(m as Map<String, dynamic>))
          .toList();

      // Compute item counts from inventory_items
      if (cats.isNotEmpty) {
        try {
          final countResponse = await _client
              .from('inventory_items')
              .select('category')
              .eq('store_id', storeId);

          final countMap = <String, int>{};
          for (final row in (countResponse as List)) {
            final cat = row['category'] as String? ?? '';
            if (cat.isNotEmpty) {
              countMap[cat] = (countMap[cat] ?? 0) + 1;
            }
          }
          for (final cat in cats) {
            cat.itemCount = countMap[cat.name] ?? 0;
          }
        } catch (_) {
          // item_count stays 0 if count query fails
        }
      }

      return cats;
    } catch (e) {
      return [];
    }
  }

  Future<CategoryModel?> createCategory(CategoryModel cat) async {
    if (cat.storeId.isEmpty) return null;
    final trimmedName = cat.name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 60) return null;
    try {
      final response = await _client
          .from('categories')
          .insert(cat.toInsertMap())
          .select()
          .single();

      return CategoryModel.fromMap(response);
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<bool> deleteCategory(String categoryId, String storeId) async {
    if (storeId.isEmpty || categoryId.isEmpty) return false;
    try {
      await _client
          .from('categories')
          .delete()
          .eq('id', categoryId)
          .eq('store_id', storeId); // ← security: scope to store
      return true;
    } catch (e) {
      return false;
    }
  }
}
