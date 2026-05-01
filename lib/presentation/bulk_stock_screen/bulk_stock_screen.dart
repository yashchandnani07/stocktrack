import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/inventory_service.dart';
import '../../../services/permission_service.dart';
import '../../../services/stock_session_service.dart';
import '../../../theme/app_theme.dart';

/// Screen for bulk stock in / stock out selection
class BulkStockScreen extends StatefulWidget {
  const BulkStockScreen({super.key});

  @override
  State<BulkStockScreen> createState() => _BulkStockScreenState();
}

class _BulkStockScreenState extends State<BulkStockScreen> {
  late String _sessionType;
  late String _storeId;
  late String _storeName;
  late String _userId;
  late String _userName;
  late String _userRole;
  late List<InventoryItem> _allItems;

  String _searchQuery = '';
  final Map<String, double> _selectedQuantities = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isSubmitting = false;
  String? _validationError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    _sessionType = args['sessionType'] as String? ?? 'IN';
    _storeId = args['storeId'] as String? ?? '';
    _storeName = args['storeName'] as String? ?? '';
    _userId = args['userId'] as String? ?? '';
    _userName = args['userName'] as String? ?? '';
    _userRole = args['userRole'] as String? ?? 'Staff';
    _allItems = (args['items'] as List<InventoryItem>?) ?? [];
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<InventoryItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _allItems;
    final q = _searchQuery.toLowerCase();
    return _allItems.where((item) {
      return item.name.toLowerCase().contains(q) ||
          (item.barcode?.contains(q) ?? false) ||
          item.category.toLowerCase().contains(q);
    }).toList();
  }

  List<InventoryItem> get _selectedItems {
    return _allItems
        .where((i) => _selectedQuantities.containsKey(i.id))
        .toList();
  }

  void _toggleItem(InventoryItem item) {
    setState(() {
      if (_selectedQuantities.containsKey(item.id)) {
        _selectedQuantities.remove(item.id);
        _controllers[item.id]?.dispose();
        _controllers.remove(item.id);
      } else {
        _selectedQuantities[item.id] = 1.0;
        _controllers[item.id] = TextEditingController(text: '1');
      }
      _validationError = null;
    });
  }

  void _updateQuantity(String itemId, String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      _selectedQuantities[itemId] = parsed;
    }
    _validationError = null;
  }

  String? _validate() {
    if (_selectedQuantities.isEmpty) {
      return 'Please select at least one item.';
    }
    for (final entry in _selectedQuantities.entries) {
      final item = _allItems.firstWhere(
        (i) => i.id == entry.key,
        orElse: () => _allItems.first,
      );
      final qty = entry.value;
      if (qty <= 0) {
        return 'Quantity for "${item.name}" must be greater than 0.';
      }
      if (qty.isNaN || qty.isInfinite) {
        return 'Invalid quantity for "${item.name}".';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    // Logic-level permission check — re-verify before every submission
    final perm = PermissionService.instance;
    if (!perm.canPerformAnyAction) {
      setState(
        () => _validationError = perm.denialReason('perform stock operations'),
      );
      return;
    }
    if (_sessionType == 'IN' && !perm.canStockIn) {
      setState(() => _validationError = perm.denialReason('perform stock in'));
      return;
    }
    if (_sessionType == 'OUT' && !perm.canStockOut) {
      setState(() => _validationError = perm.denialReason('perform stock out'));
      return;
    }

    final error = _validate();
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    final sessionItems = _selectedItems.map((item) {
      return StockSessionItem(
        itemId: item.id,
        itemName: item.name,
        category: item.category,
        quantity: _selectedQuantities[item.id] ?? 1.0,
        unit: item.unit,
      );
    }).toList();

    final result = await StockSessionService.instance.submitSession(
      storeId: _storeId,
      sessionType: _sessionType,
      userId: _userId,
      userName: _userName,
      userRole: _userRole,
      storeName: _storeName,
      items: sessionItems,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.session != null) {
      Navigator.pushReplacementNamed(
        context,
        '/stock-session-success',
        arguments: {
          'session': result.session,
          'storeName': _storeName,
          'failedItems': result.failedItems,
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Session failed. Please try again.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStockIn = _sessionType == 'IN';
    final accentColor = isStockIn ? AppTheme.secondary : AppTheme.error;
    final selectedCount = _selectedQuantities.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStockIn ? 'Stock In' : 'Stock Out',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              _storeName,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (selectedCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withAlpha(80)),
              ),
              child: Text(
                '$selectedCount selected',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppTheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, barcode or category...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.onSurfaceMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ),

          // Validation error
          if (_validationError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationError!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Selected items section
          if (_selectedItems.isNotEmpty) ...[
            _buildSectionHeader(
              'Selected Items (${_selectedItems.length})',
              accentColor,
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedItems.length,
                itemBuilder: (_, i) =>
                    _buildSelectedChip(_selectedItems[i], accentColor),
              ),
            ),
            const Divider(color: AppTheme.outlineVariant, height: 1),
          ],

          // Items list
          _buildSectionHeader(
            'All Items (${_filteredItems.length})',
            AppTheme.onSurfaceMuted,
          ),
          Expanded(
            child: _allItems.isEmpty
                ? Center(
                    child: Text(
                      'No items in inventory',
                      style: GoogleFonts.dmSans(
                        color: AppTheme.onSurfaceMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : _filteredItems.isEmpty
                ? Center(
                    child: Text(
                      'No items match "$_searchQuery"',
                      style: GoogleFonts.dmSans(
                        color: AppTheme.onSurfaceMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: _filteredItems.length,
                    itemBuilder: (_, i) =>
                        _buildItemTile(_filteredItems[i], accentColor),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSubmitBar(isStockIn, accentColor),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSelectedChip(InventoryItem item, Color accentColor) {
    final controller = _controllers[item.id]!;
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _toggleItem(item),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.category,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppTheme.onSurfaceMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: (v) => _updateQuantity(item.id, v),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: accentColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.unit,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(InventoryItem item, Color accentColor) {
    final isSelected = _selectedQuantities.containsKey(item.id);
    return GestureDetector(
      onTap: () => _toggleItem(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withAlpha(15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor.withAlpha(120)
                : AppTheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? accentColor : AppTheme.outline,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item.category,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppTheme.onSurfaceMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stock: ${formatQuantity(item.quantity)} ${item.unit}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected && _controllers.containsKey(item.id))
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _controllers[item.id],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: (v) => _updateQuantity(item.id, v),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    suffixText: item.unit,
                    suffixStyle: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ),
              )
            else
              Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.onSurfaceMuted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar(bool isStockIn, Color accentColor) {
    final selectedCount = _selectedQuantities.length;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$selectedCount item${selectedCount == 1 ? '' : 's'} selected',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  isStockIn ? 'Will add to stock' : 'Will remove from stock',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting || selectedCount == 0 ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accentColor.withAlpha(60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isStockIn
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Processing...'
                    : isStockIn
                    ? 'Stock In'
                    : 'Stock Out',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
