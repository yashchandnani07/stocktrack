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

// ── Robust JSON parsers ──────────────────────────────────────────────────────
// Supabase returns NUMERIC columns as a JSON number that Dart parses as
// `double` (e.g. `5.0`) when the column has a decimal default — even if the
// stored value has no fractional part. Using `as int?` then throws
// "type 'double' is not a subtype of type 'int?' in type cast", which is
// exactly the user-visible "Create failed: …" error reported on Android.
//
// Every numeric/string read from a Supabase row MUST go through these helpers
// so the parse never throws on a representation surprise (int↔double↔string).
double _asDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  }
  return fallback;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

String? _asStringNullable(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

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
    // Every numeric/string read goes through the _as* helpers so the parse
    // can't blow up on int↔double↔string surprises from Postgres NUMERIC
    // columns. See the comment on `_asInt` at the top of this file for the
    // exact bug ("Create failed: type 'double' is not a subtype of 'int?'").
    DateTime parsedUpdatedAt;
    final rawUpdatedAt = map['updated_at'];
    if (rawUpdatedAt is String && rawUpdatedAt.isNotEmpty) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }
    return InventoryItem(
      id: _asString(map['id']),
      storeId: _asString(map['store_id']),
      name: _asString(map['name']),
      category: _asString(map['category'], 'General'),
      quantity: _roundQty(_asDouble(map['quantity'])),
      // low_stock_threshold column is NUMERIC(10,2) in DB but we keep this
      // a Dart int — coerce via num.toInt() so a `5.0` from Postgres parses
      // cleanly. This was the original "Create failed: type 'double' …" bug.
      lowStockThreshold: _asInt(map['low_stock_threshold'], 5),
      unit: _asString(map['unit'], 'pcs'),
      barcode: _asStringNullable(map['barcode']),
      lastUpdated: parsedUpdatedAt,
      updatedBy: _asString(map['updated_by']),
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
    // color_value is BIGINT in DB; icon_code is INTEGER in DB; item_count
    // is computed in Dart and never present in the row. All numeric reads go
    // through _asInt so the parse can't throw on int↔double↔string surprises.
    return CategoryModel(
      id: _asString(map['id']),
      storeId: _asString(map['store_id']),
      name: _asString(map['name']),
      color: Color(_asInt(map['color_value'], 0xFF3B5BDB)),
      icon: IconData(
        _asInt(map['icon_code'], Icons.category_rounded.codePoint),
        fontFamily: 'MaterialIcons',
      ),
      itemCount: _asInt(map['item_count'], 0),
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

      // Per-row try/catch: a single corrupt row must NOT blank the entire
      // list. Previously, `(response as List).map(...).toList()` would throw
      // on the first row that failed to parse (e.g. low_stock_threshold cast)
      // and the outer catch would return []. The user then saw "no items"
      // even though items existed in the DB — this is the second face of the
      // same bug as the "Create failed" toast on Android.
      final items = <InventoryItem>[];
      var parseFailures = 0;
      for (final raw in (response as List)) {
        try {
          items.add(InventoryItem.fromMap(raw as Map<String, dynamic>));
        } catch (e) {
          parseFailures++;
          debugPrint(
            '[InventoryService] fetchItems — parse FAILED for row: $raw — $e',
          );
        }
      }
      debugPrint(
        '[InventoryService] fetchItems — returned ${items.length} item(s) '
        '(${parseFailures} skipped) for store_id: "$storeId" '
        '(user_id: ${user?.id ?? "null"})',
      );
      return items;
    } catch (e) {
      debugPrint('[InventoryService] fetchItems — error: $e');
      return [];
    }
  }

  Future<InventoryItem?> createItem(InventoryItem item) async {
    // Reset before each attempt so the UI never reports stale errors from a
    // previous unrelated call.
    lastError = null;
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
      debugPrint('[InventoryService] createItem — REJECT: $lastError');
      return null;
    }
    if (activeStore != null && activeStore.id != item.storeId) {
      // Refuse to write to a store that doesn't match the active context.
      // This is what prevents the "created on web, invisible on mobile"
      // class of bugs at write-time.
      lastError =
          'Store context mismatch. Please re-select your store and try again.';
      debugPrint(
        '[InventoryService] createItem — REJECT: item.storeId '
        '"${item.storeId}" != active store "${activeStore.id}". '
        'Refusing to create item under a stale store context.',
      );
      return null;
    }
    // Validate name
    final trimmedName = item.name.trim();
    if (trimmedName.isEmpty) {
      lastError = 'Item name cannot be empty.';
      debugPrint('[InventoryService] createItem — REJECT: $lastError');
      return null;
    }
    if (trimmedName.length > kMaxItemNameLength) {
      lastError = 'Item name is too long (max $kMaxItemNameLength characters).';
      debugPrint('[InventoryService] createItem — REJECT: $lastError');
      return null;
    }
    try {
      final response = await _client
          .from('inventory_items')
          .insert(item.toInsertMap())
          .select()
          .single();

      final created = InventoryItem.fromMap(response);
      debugPrint(
        '[InventoryService] createItem — OK: id="${created.id}" '
        'store_id="${created.storeId}" name="${created.name}"',
      );
      return created;
    } catch (e) {
      // Surface the full error to logs so adb logcat shows the real cause
      // (RLS, unique-violation, network, etc.) instead of a generic null.
      lastError = e.toString();
      debugPrint(
        '[InventoryService] createItem — EXCEPTION '
        'store_id="${item.storeId}" name="${item.name}" — $e',
      );
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
    if (storeId.isEmpty) {
      debugPrint(
        '[InventoryService] fetchCategories — ABORT: storeId is EMPTY.',
      );
      return [];
    }
    try {
      // Fetch categories and compute item_count from inventory_items
      final response = await _client
          .from('categories')
          .select()
          .eq('store_id', storeId)
          .order('name', ascending: true);

      // Per-row try/catch — same defense as fetchItems.
      final cats = <CategoryModel>[];
      var parseFailures = 0;
      for (final raw in (response as List)) {
        try {
          cats.add(CategoryModel.fromMap(raw as Map<String, dynamic>));
        } catch (e) {
          parseFailures++;
          debugPrint(
            '[InventoryService] fetchCategories — parse FAILED for row: $raw — $e',
          );
        }
      }
      if (parseFailures > 0) {
        debugPrint(
          '[InventoryService] fetchCategories — skipped $parseFailures '
          'unparseable row(s) for store_id "$storeId"',
        );
      }

      // Compute item counts from inventory_items
      if (cats.isNotEmpty) {
        try {
          final countResponse = await _client
              .from('inventory_items')
              .select('category')
              .eq('store_id', storeId);

          final countMap = <String, int>{};
          for (final row in (countResponse as List)) {
            final cat = _asString(row['category']);
            if (cat.isNotEmpty) {
              countMap[cat] = (countMap[cat] ?? 0) + 1;
            }
          }
          for (final cat in cats) {
            cat.itemCount = countMap[cat.name] ?? 0;
          }
        } catch (e) {
          debugPrint(
            '[InventoryService] fetchCategories — count query FAILED: $e',
          );
          // item_count stays 0 if count query fails
        }
      }

      return cats;
    } catch (e) {
      debugPrint('[InventoryService] fetchCategories — error: $e');
      return [];
    }
  }

  Future<CategoryModel?> createCategory(CategoryModel cat) async {
    lastError = null;
    if (cat.storeId.isEmpty) {
      lastError = 'Cannot create category without a store.';
      debugPrint('[InventoryService] createCategory — REJECT: $lastError');
      return null;
    }
    final trimmedName = cat.name.trim();
    if (trimmedName.isEmpty) {
      lastError = 'Category name cannot be empty.';
      debugPrint('[InventoryService] createCategory — REJECT: $lastError');
      return null;
    }
    if (trimmedName.length > 60) {
      lastError = 'Category name is too long (max 60 characters).';
      debugPrint('[InventoryService] createCategory — REJECT: $lastError');
      return null;
    }
    try {
      final response = await _client
          .from('categories')
          .insert(cat.toInsertMap())
          .select()
          .single();

      final created = CategoryModel.fromMap(response);
      debugPrint(
        '[InventoryService] createCategory — OK: id="${created.id}" '
        'store_id="${created.storeId}" name="${created.name}"',
      );
      return created;
    } catch (e) {
      lastError = e.toString();
      debugPrint(
        '[InventoryService] createCategory — EXCEPTION '
        'store_id="${cat.storeId}" name="${cat.name}" — $e',
      );
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
