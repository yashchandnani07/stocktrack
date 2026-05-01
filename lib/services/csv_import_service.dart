import 'dart:convert';

import 'package:flutter/material.dart';

import './inventory_service.dart';

/// Represents a single parsed CSV row with validation state
class CsvImportRow {
  final int rowIndex;
  final String rawItemName;
  final String rawQuantity;
  final String? rawCategory; // null means column not present in CSV
  final String? itemName; // null if invalid
  final double? quantity; // null if invalid — supports decimals
  final String? category; // trimmed category value (may be null/empty)
  final List<String> errors;
  final bool isValid;

  const CsvImportRow({
    required this.rowIndex,
    required this.rawItemName,
    required this.rawQuantity,
    this.rawCategory,
    this.itemName,
    this.quantity,
    this.category,
    required this.errors,
    required this.isValid,
  });
}

/// Summary returned after a completed bulk import
class BulkImportSummary {
  final int totalRows;
  final int importedCount;
  final int skippedCount;
  final int createdCount;
  final int updatedCount;
  final List<String> errors;

  const BulkImportSummary({
    required this.totalRows,
    required this.importedCount,
    required this.skippedCount,
    required this.createdCount,
    required this.updatedCount,
    required this.errors,
  });
}

/// Service for parsing CSV files and bulk-importing inventory items
class CsvImportService {
  static CsvImportService? _instance;
  static CsvImportService get instance => _instance ??= CsvImportService._();
  CsvImportService._();

  /// Rounds a quantity to at most 2 decimal places to avoid floating-point drift.
  double _roundQty(double v) => (v * 100).roundToDouble() / 100;

  /// Parse raw CSV bytes into validated rows.
  /// Expected columns: item_name, quantity[, category] (header row required)
  List<CsvImportRow> parseBytes(List<int> bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    // Parse header
    final header = _splitCsvLine(lines[0]);
    final nameIdx = _findColumnIndex(header, ['item_name', 'name', 'item']);
    final qtyIdx = _findColumnIndex(header, ['quantity', 'qty', 'stock']);
    final catIdx = _findColumnIndex(header, ['category', 'cat']);

    if (nameIdx == -1 || qtyIdx == -1) {
      // Return a single error row indicating bad header
      return [
        CsvImportRow(
          rowIndex: 0,
          rawItemName: '',
          rawQuantity: '',
          errors: [
            'CSV must have "item_name" and "quantity" columns in the header row.',
          ],
          isValid: false,
        ),
      ];
    }

    final rows = <CsvImportRow>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      final rawName = nameIdx < cols.length ? cols[nameIdx].trim() : '';
      final rawQty = qtyIdx < cols.length ? cols[qtyIdx].trim() : '';
      // category column is optional — null if column not present in CSV
      final rawCat = catIdx != -1
          ? (catIdx < cols.length ? cols[catIdx].trim() : '')
          : null;

      final errors = <String>[];
      String? validName;
      double? validQty;

      if (rawName.isEmpty) {
        errors.add('item_name is empty');
      } else if (rawName.length > kMaxItemNameLength) {
        errors.add('item_name exceeds $kMaxItemNameLength characters');
      } else {
        validName = rawName;
      }

      if (rawQty.isEmpty) {
        errors.add('quantity is missing');
      } else {
        // Accept both integers and decimal values (e.g. 10, 5.5, 88.9)
        final parsed = double.tryParse(rawQty);
        if (parsed == null) {
          errors.add('"$rawQty" is not a valid number');
        } else if (parsed < 0) {
          errors.add('quantity cannot be negative');
        } else if (parsed > kMaxQuantity) {
          errors.add('quantity exceeds maximum ($kMaxQuantity)');
        } else {
          // Round to 2 decimal places to avoid floating-point drift
          validQty = _roundQty(parsed);
        }
      }

      // category: use value exactly as provided (trimmed), empty string → treat as not provided
      final validCategory = (rawCat != null && rawCat.isNotEmpty)
          ? rawCat
          : null;

      rows.add(
        CsvImportRow(
          rowIndex: i,
          rawItemName: rawName,
          rawQuantity: rawQty,
          rawCategory: rawCat,
          itemName: validName,
          quantity: validQty,
          category: validCategory,
          errors: errors,
          isValid: errors.isEmpty,
        ),
      );
    }
    return rows;
  }

  /// Execute the bulk import for valid rows into the given store.
  /// Strategy: if item with same name exists → add quantity (stock in), update category if provided.
  ///           if item does not exist → create new item (with category if provided).
  /// Categories are auto-created if they don't already exist.
  /// Returns a summary of the operation.
  Future<BulkImportSummary> executeImport({
    required String storeId,
    required String updatedBy,
    required List<CsvImportRow> rows,
  }) async {
    final validRows = rows.where((r) => r.isValid).toList();
    final skipped = rows.length - validRows.length;

    if (storeId.isEmpty || validRows.isEmpty) {
      return BulkImportSummary(
        totalRows: rows.length,
        importedCount: 0,
        skippedCount: skipped,
        createdCount: 0,
        updatedCount: 0,
        errors: ['No valid rows to import.'],
      );
    }

    // Fetch existing items once to avoid N+1 lookups
    final existing = await InventoryService.instance.fetchItems(storeId);
    // Build lookup map using fully-normalized keys (trim + lowercase + strip hidden chars)
    final nameMap = <String, InventoryItem>{};
    for (final item in existing) {
      nameMap[_normalizeForLookup(item.name)] = item;
    }

    // Fetch existing categories once; build a name→id map for quick lookup
    final existingCategories = await InventoryService.instance.fetchCategories(
      storeId,
    );
    final categoryNameMap =
        <String, String>{}; // normalized-name → original-case name
    for (final cat in existingCategories) {
      categoryNameMap[_normalizeForLookup(cat.name)] = cat.name;
    }

    int created = 0;
    int updated = 0;
    final importErrors = <String>[];

    for (final row in validRows) {
      // Normalize for lookup ONLY — stored value stays as-is
      final normalizedName = _normalizeForLookup(row.itemName!);
      final existingItem = nameMap[normalizedName];

      // Resolve category: auto-create if provided and not yet existing
      String resolvedCategory = 'General';
      if (row.category != null && row.category!.isNotEmpty) {
        final normalizedCat = _normalizeForLookup(row.category!);
        if (categoryNameMap.containsKey(normalizedCat)) {
          // Use the existing category's original-case name
          resolvedCategory = categoryNameMap[normalizedCat]!;
        } else {
          // Auto-create the new category
          InventoryService.instance.lastError = null;
          final newCat = CategoryModel(
            id: '',
            storeId: storeId,
            name: row.category!,
            color: const Color(0xFF3B5BDB),
            icon: Icons.category_rounded,
            itemCount: 0,
          );
          final saved = await InventoryService.instance.createCategory(newCat);
          if (saved != null) {
            categoryNameMap[normalizedCat] = row.category!;
            resolvedCategory = row.category!;
          } else {
            // Category creation failed — fall back to provided name anyway
            resolvedCategory = row.category!;
          }
        }
      }

      if (existingItem != null) {
        // Determine the category to use for the update
        final categoryForUpdate =
            row.category != null && row.category!.isNotEmpty
            ? resolvedCategory
            : existingItem.category;

        // Apply stock delta
        final result = await InventoryService.instance.applyStockDelta(
          itemId: existingItem.id,
          storeId: storeId,
          delta: row.quantity!,
          updatedBy: updatedBy,
        );

        if (result.success) {
          // If category changed, also update the item's category field
          if (categoryForUpdate != existingItem.category) {
            final categoryUpdated = InventoryItem(
              id: existingItem.id,
              storeId: existingItem.storeId,
              name: existingItem.name,
              category: categoryForUpdate,
              quantity: result.newQuantity ?? existingItem.quantity,
              lowStockThreshold: existingItem.lowStockThreshold,
              unit: existingItem.unit,
              barcode: existingItem.barcode,
              lastUpdated: DateTime.now(),
              updatedBy: updatedBy,
            );
            await InventoryService.instance.updateItem(categoryUpdated);
          }
          updated++;
          nameMap[normalizedName] = existingItem.copyWith(
            quantity: result.newQuantity ?? existingItem.quantity,
          );
        } else {
          importErrors.add(
            'Row ${row.rowIndex}: Failed to update "${row.itemName}" — ${result.error}',
          );
        }
      } else {
        // Create new item with exact decimal quantity and resolved category
        InventoryService.instance.lastError = null;
        final newItem = InventoryItem(
          id: '',
          storeId: storeId,
          name: row.itemName!,
          category: resolvedCategory,
          quantity: row.quantity!,
          lowStockThreshold: 5,
          unit: 'pcs',
          lastUpdated: DateTime.now(),
          updatedBy: updatedBy,
        );
        final saved = await InventoryService.instance.createItem(newItem);
        if (saved != null) {
          created++;
          nameMap[normalizedName] = saved;
        } else {
          // Surface the exact database error instead of a generic message
          final dbError = InventoryService.instance.lastError;
          final reason = (dbError != null && dbError.isNotEmpty)
              ? dbError
              : 'Unknown error';
          importErrors.add(
            'Row ${row.rowIndex}: Failed to create "${row.itemName}" — $reason',
          );
        }
      }
    }

    return BulkImportSummary(
      totalRows: rows.length,
      importedCount: created + updated,
      skippedCount: skipped,
      createdCount: created,
      updatedCount: updated,
      errors: importErrors,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Normalize a string for existence-check comparisons ONLY.
  /// Strips BOM, non-breaking spaces, and other Unicode whitespace,
  /// then trims ASCII whitespace and lowercases.
  /// The original value is NEVER modified — this is used only for map lookups.
  String _normalizeForLookup(String value) {
    // Remove BOM (U+FEFF) and zero-width chars that survive normal trim()
    // Use actual Unicode code points (not literal backslash-u strings)
    var normalized = value
        .replaceAll('\\uFEFF', '') // BOM
        .replaceAll('\\u00A0', ' ') // non-breaking space → regular space
        .replaceAll('\\u200B', '') // zero-width space
        .replaceAll('\\u200C', '') // zero-width non-joiner
        .replaceAll('\\u200D', '') // zero-width joiner
        .replaceAll('\\u2060', '') // word joiner
        .replaceAll('\\uFFFD', ''); // replacement character
    return normalized.trim().toLowerCase();
  }

  int _findColumnIndex(List<String> header, List<String> candidates) {
    for (int i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase().trim();
      if (candidates.contains(h)) return i;
    }
    return -1;
  }

  /// Simple CSV line splitter that handles quoted fields
  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }
}
