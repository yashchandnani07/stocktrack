import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/activity_log_service.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../services/realtime_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_skeleton_widget.dart';
import './widgets/bulk_import_sheet_widget.dart';
import './widgets/category_filter_widget.dart';
import './widgets/inventory_item_card_widget.dart';
import './widgets/inventory_search_bar_widget.dart';
import './widgets/inventory_summary_widget.dart';
import './widgets/stock_action_sheet_widget.dart';
import './widgets/recent_activity_widget.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String _userRole = 'Owner';
  String _userName = '';
  String _userId = '';
  String _storeId = '';
  String _storeName = '';
  List<InventoryItem> _items = [];
  bool _realtimeSubscribed = false;

  @override
  void dispose() {
    RealtimeService.instance.unsubscribe('inventory_items_$_storeId');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final argsMap = args is Map ? args : const {};

    // ── SINGLE SOURCE OF TRUTH ───────────────────────────────────────────────
    // StoreService.instance.currentStore is the authoritative store context.
    // Route args are only used to populate it when the screen is entered fresh
    // (e.g. immediately after login or store-selection). If args ever disagree
    // with the singleton, the singleton wins and we log loudly so divergences
    // surface in production logs.
    final argsStoreId = argsMap['storeId'] as String? ?? '';
    final serviceStore = StoreService.instance.currentStore;
    final serviceStoreId = serviceStore?.id ?? '';

    // If StoreService is empty but args carry a storeId, this is the only
    // case where args populate the singleton (immediately after login /
    // store-selection where setCurrentStore was already called by the nav).
    String resolvedStoreId;
    String resolvedStoreName;
    if (serviceStoreId.isNotEmpty) {
      if (argsStoreId.isNotEmpty && argsStoreId != serviceStoreId) {
        debugPrint(
          '[InventoryScreen] args.storeId="$argsStoreId" disagrees with '
          'StoreService.currentStore.id="$serviceStoreId" — using SINGLETON '
          '(single source of truth). Args may be stale.',
        );
      }
      resolvedStoreId = serviceStoreId;
      resolvedStoreName = serviceStore!.name;
    } else if (argsStoreId.isNotEmpty) {
      // Should not normally happen — navigator should set the singleton first
      debugPrint(
        '[InventoryScreen] StoreService empty but args have storeId="$argsStoreId" '
        '— honoring args but will redirect on next frame if singleton stays empty.',
      );
      resolvedStoreId = argsStoreId;
      resolvedStoreName = argsMap['storeName'] as String? ?? '';
    } else {
      resolvedStoreId = '';
      resolvedStoreName = '';
    }

    // ── BLOCK ACTIONS WHEN STORE IS NOT SET ──────────────────────────────────
    // If we still have no store, we cannot safely render this screen — every
    // query / mutation here is store-scoped. Redirect to the store selector.
    if (resolvedStoreId.isEmpty) {
      debugPrint(
        '[InventoryScreen] No active store — redirecting to selectStoreScreen. '
        'user_id: ${Supabase.instance.client.auth.currentUser?.id ?? "null"}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          Navigator.pushReplacementNamed(context, AppRoutes.signUpLoginScreen);
          return;
        }
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.selectStoreScreen,
          arguments: {
            'userName':
                user.userMetadata?['full_name'] as String? ??
                user.email?.split('@').first ??
                'User',
            'userId': user.id,
          },
        );
      });
      return;
    }

    // Resolve identity
    final newRole = argsMap['role'] as String? ?? StoreService.instance.currentRole;
    String newUserId = argsMap['userId'] as String? ?? '';
    String newUserName = argsMap['userName'] as String? ?? '';
    if (newUserId.isEmpty) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        newUserId = user.id;
        if (newUserName.isEmpty) {
          newUserName =
              user.userMetadata?['full_name'] as String? ??
              user.email?.split('@').first ??
              'User';
        }
      }
    }
    final isActive = argsMap['isActive'] as bool? ?? true;

    final storeChanged = resolvedStoreId != _storeId;
    final roleChanged = newRole != _userRole;

    _userRole = newRole;
    _userName = newUserName;
    _userId = newUserId;
    _storeId = resolvedStoreId;
    _storeName = resolvedStoreName;

    debugPrint(
      '[InventoryScreen] context resolved — '
      'user_id: $_userId store_id: $_storeId store_name: "$_storeName" '
      'role: $_userRole isActive: $isActive '
      'storeChanged=$storeChanged roleChanged=$roleChanged',
    );

    PermissionService.instance.setUser(
      role: _userRole,
      userId: _userId,
      isActive: isActive,
      storeId: _storeId,
    );

    // Reload if store changed, role changed, or on first load
    if (storeChanged || roleChanged || _isLoading) {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    StoreService.instance.logContext('InventoryScreen._loadItems');
    if (_storeId.isEmpty) {
      debugPrint('[InventoryScreen] _loadItems aborted: _storeId is empty');
      return;
    }
    // Unsubscribe existing realtime channel before re-subscribing
    // (handles store switch without screen rebuild)
    if (_realtimeSubscribed) {
      RealtimeService.instance.unsubscribe('inventory_items_$_storeId');
      _realtimeSubscribed = false;
    }
    setState(() => _isLoading = true);
    final items = await InventoryService.instance.fetchItems(_storeId);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
      _subscribeRealtime();
    }
  }

  void _subscribeRealtime() {
    if (_realtimeSubscribed || _storeId.isEmpty) return;
    _realtimeSubscribed = true;

    RealtimeService.instance.subscribeToTable(
      channelName: 'inventory_items_$_storeId',
      table: 'inventory_items',
      storeId: _storeId,
      onInsert: (record) {
        if (!mounted) return;
        final newItem = InventoryItem.fromMap(record);
        setState(() {
          // Avoid duplicates
          if (!_items.any((i) => i.id == newItem.id)) {
            _items.insert(0, newItem);
          }
        });
      },
      onUpdate: (record) {
        if (!mounted) return;
        final updated = InventoryItem.fromMap(record);
        setState(() {
          final idx = _items.indexWhere((i) => i.id == updated.id);
          if (idx != -1) {
            _items[idx] = updated;
          }
        });
      },
      onDelete: (record) {
        if (!mounted) return;
        final deletedId = record['id'] as String?;
        if (deletedId != null) {
          setState(() => _items.removeWhere((i) => i.id == deletedId));
        }
      },
    );
  }

  List<String> get _categories {
    final cats = _items.map((e) => e.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  List<InventoryItem> get _filteredItems {
    return _items.where((item) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.barcode?.contains(_searchQuery) ?? false);
      final matchesCategory =
          _selectedCategory == 'All' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _onStockAction(InventoryItem item, bool isStockIn) {
    final perm = PermissionService.instance;
    // Re-check disabled status before every action (handles mid-session disable)
    if (!perm.canPerformAnyAction) {
      _showDenied(perm.denialReason('perform any action'));
      return;
    }
    if (isStockIn && !perm.canStockIn) {
      _showDenied(perm.denialReason('perform stock in'));
      return;
    }
    if (!isStockIn && !perm.canStockOut) {
      _showDenied(perm.denialReason('perform stock out'));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StockActionSheet(
        item: item,
        isStockIn: isStockIn,
        userRole: _userRole,
        userName: _userName,
        onConfirm: (quantity) async {
          // Use atomic delta update to prevent race conditions
          final delta = isStockIn ? quantity : -quantity;
          final result = await InventoryService.instance.applyStockDelta(
            itemId: item.id,
            storeId: _storeId,
            delta: delta,
            updatedBy: _userName,
          );

          if (!mounted) return;

          if (!result.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'Stock update failed'),
                backgroundColor: AppTheme.error,
              ),
            );
            return;
          }

          final newQty = result.newQuantity ?? item.quantity;
          setState(() {
            final index = _items.indexWhere((i) => i.id == item.id);
            if (index != -1) {
              _items[index] = item.copyWith(
                quantity: newQty,
                lastUpdated: DateTime.now(),
                updatedBy: _userName,
              );
            }
          });
          ActivityLogService.instance.log(
            storeId: _storeId,
            userId: _userId,
            userName: _userName,
            userRole: _userRole,
            actionType: isStockIn
                ? ActivityActionType.stockIn
                : ActivityActionType.stockOut,
            itemId: item.id,
            itemName: item.name,
            quantity: quantity, // pass double directly — no truncation
            unit: item.unit,
          );
        },
      ),
    );
  }

  void _navigateToAddItem() {
    if (!PermissionService.instance.canCreateItem) {
      _showDenied(PermissionService.instance.denialReason('add items'));
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.addEditItemScreen,
      arguments: {
        'role': _userRole,
        'userName': _userName,
        'userId': _userId,
        'storeId': _storeId,
        'storeName': _storeName,
        'categories': _categories.where((c) => c != 'All').toList(),
        'onSave': (InventoryItem newItem) {
          setState(() => _items.insert(0, newItem));
          ActivityLogService.instance.log(
            storeId: _storeId,
            userId: _userId,
            userName: _userName,
            userRole: _userRole,
            actionType: ActivityActionType.itemCreated,
            itemId: newItem.id,
            itemName: newItem.name,
          );
        },
      },
    );
  }

  void _navigateToEditItem(InventoryItem item) {
    if (!PermissionService.instance.canEditItem) {
      _showDenied(PermissionService.instance.denialReason('edit items'));
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.addEditItemScreen,
      arguments: {
        'item': item,
        'role': _userRole,
        'userName': _userName,
        'userId': _userId,
        'storeId': _storeId,
        'storeName': _storeName,
        'categories': _categories.where((c) => c != 'All').toList(),
        'onSave': (InventoryItem updated) {
          setState(() {
            final idx = _items.indexWhere((i) => i.id == updated.id);
            if (idx != -1) _items[idx] = updated;
          });
          ActivityLogService.instance.log(
            storeId: _storeId,
            userId: _userId,
            userName: _userName,
            userRole: _userRole,
            actionType: ActivityActionType.itemEdited,
            itemId: updated.id,
            itemName: updated.name,
          );
        },
        'onDelete': (String id) {
          final deletedItem = _items.firstWhere(
            (i) => i.id == id,
            orElse: () => item,
          );
          setState(() => _items.removeWhere((i) => i.id == id));
          ActivityLogService.instance.log(
            storeId: _storeId,
            userId: _userId,
            userName: _userName,
            userRole: _userRole,
            actionType: ActivityActionType.itemDeleted,
            itemId: id,
            itemName: deletedItem.name,
          );
        },
      },
    );
  }

  void _showBulkImport() {
    if (!PermissionService.instance.canCreateItem) {
      _showDenied(PermissionService.instance.denialReason('import items'));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BulkImportSheet(
        storeId: _storeId,
        userId: _userId,
        userName: _userName,
        userRole: _userRole,
        onImportComplete: _loadItems,
      ),
    );
  }

  void _navigateBulkStock(bool isStockIn) {
    final perm = PermissionService.instance;
    if (!perm.canPerformAnyAction) {
      _showDenied(perm.denialReason('perform stock operations'));
      return;
    }
    if (isStockIn && !perm.canStockIn) {
      _showDenied(perm.denialReason('perform stock in'));
      return;
    }
    if (!isStockIn && !perm.canStockOut) {
      _showDenied(perm.denialReason('perform stock out'));
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.bulkStockScreen,
      arguments: {
        'sessionType': isStockIn ? 'IN' : 'OUT',
        'storeId': _storeId,
        'storeName': _storeName,
        'userId': _userId,
        'userName': _userName,
        'userRole': _userRole,
        'items': List<InventoryItem>.from(_items),
      },
    ).then((_) => _loadItems());
  }

  void _navigateSessionHistory() {
    Navigator.pushNamed(
      context,
      AppRoutes.stockSessionHistory,
      arguments: {'storeId': _storeId, 'storeName': _storeName},
    );
  }

  void _showDenied(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  void _switchStore() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.selectStoreScreen,
      arguments: {'userName': _userName, 'userId': _userId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final filtered = _filteredItems;
    final perm = PermissionService.instance;

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: AppNavigation(
        currentIndex: 0,
        userRole: _userRole,
        userName: _userName,
        userId: _userId,
        isActive: perm.isActive,
        storeId: _storeId,
        storeName: _storeName,
      ),
      floatingActionButton: perm.canCreateItem
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            )
          : null,
      body: isTablet
          ? Row(
              children: [
                AppNavigation(
                  currentIndex: 0,
                  userRole: _userRole,
                  userName: _userName,
                  userId: _userId,
                  isActive: perm.isActive,
                  storeId: _storeId,
                  storeName: _storeName,
                ),
                Expanded(child: _buildBody(filtered)),
              ],
            )
          : _buildBody(filtered),
    );
  }

  Widget _buildBody(List<InventoryItem> filtered) {
    final perm = PermissionService.instance;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          InventorySearchBarWidget(
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
          const SizedBox(height: 8),
          CategoryFilterWidget(
            categories: _categories,
            selected: _selectedCategory,
            onSelected: (c) => setState(() => _selectedCategory = c),
          ),
          const SizedBox(height: 8),
          if (!_isLoading) InventorySummaryWidget(items: _items),
          Expanded(
            child: _isLoading
                ? _buildSkeleton()
                : filtered.isEmpty &&
                      _searchQuery.isEmpty &&
                      _selectedCategory == 'All'
                ? _buildEmptyWithRecent(perm)
                : filtered.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No items found',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'No items match "$_searchQuery"'
                        : 'Add your first inventory item to get started.',
                    actionLabel: perm.canCreateItem ? 'Add Item' : null,
                    onAction: perm.canCreateItem ? _navigateToAddItem : null,
                  )
                : _buildItemListWithRecent(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWithRecent(PermissionService perm) {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (_userRole != 'Staff')
            RecentActivityWidget(
              userRole: _userRole,
              userId: _userId,
              userName: _userName,
              storeId: _storeId,
            ),
          EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No items yet',
            subtitle: 'Add your first inventory item to get started.',
            actionLabel: perm.canCreateItem ? 'Add Item' : null,
            onAction: perm.canCreateItem ? _navigateToAddItem : null,
          ),
        ],
      ),
    );
  }

  Widget _buildItemListWithRecent(List<InventoryItem> items) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    if (isTablet) {
      return CustomScrollView(
        slivers: [
          if (_userRole != 'Staff')
            SliverToBoxAdapter(
              child: RecentActivityWidget(
                userRole: _userRole,
                userId: _userId,
                userName: _userName,
                storeId: _storeId,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildAnimatedItem(items, i),
                childCount: items.length,
              ),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        if (_userRole != 'Staff')
          SliverToBoxAdapter(
            child: RecentActivityWidget(
              userRole: _userRole,
              userId: _userId,
              userName: _userName,
              storeId: _storeId,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildAnimatedItem(items, i),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: GoogleFonts.fraunces(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _storeName.isNotEmpty ? _storeName : 'Loading...',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '· $_userRole',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.store_outlined,
                  size: 20,
                  color: AppTheme.onSurfaceSecondary,
                ),
                onPressed: _switchStore,
                tooltip: 'Switch Store',
              ),
              if (PermissionService.instance.canCreateItem)
                IconButton(
                  icon: const Icon(
                    Icons.upload_file_rounded,
                    size: 20,
                    color: AppTheme.onSurfaceSecondary,
                  ),
                  onPressed: _showBulkImport,
                  tooltip: 'Bulk CSV Import',
                ),
              IconButton(
                icon: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: AppTheme.onSurfaceSecondary,
                ),
                onPressed: _navigateSessionHistory,
                tooltip: 'Session History',
              ),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.signUpLoginScreen,
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary.withAlpha(80)),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.fraunces(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Stock In / Stock Out bulk action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BulkActionButton(
                  label: 'Stock In',
                  icon: Icons.arrow_downward_rounded,
                  color: AppTheme.secondary,
                  bgColor: AppTheme.secondaryLight,
                  onTap: () => _navigateBulkStock(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BulkActionButton(
                  label: 'Stock Out',
                  icon: Icons.arrow_upward_rounded,
                  color: AppTheme.error,
                  bgColor: AppTheme.errorLight,
                  onTap: () => _navigateBulkStock(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, __) => const InventoryItemSkeleton(),
    );
  }

  Widget _buildAnimatedItem(List<InventoryItem> items, int i) {
    final perm = PermissionService.instance;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (i * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InventoryItemCard(
          item: items[i],
          userRole: _userRole,
          onStockIn: perm.canStockIn
              ? () => _onStockAction(items[i], true)
              : null,
          onStockOut: perm.canStockOut
              ? () => _onStockAction(items[i], false)
              : null,
          onEdit: perm.canEditItem ? () => _navigateToEditItem(items[i]) : null,
          onDelete: perm.canDeleteItem
              ? () => _confirmDeleteItem(items[i])
              : null,
        ),
      ),
    );
  }

  void _confirmDeleteItem(InventoryItem item) {
    if (!PermissionService.instance.canDeleteItem) {
      _showDenied(PermissionService.instance.denialReason('delete items'));
      return;
    }
    // Re-check disabled status
    if (!PermissionService.instance.canPerformAnyAction) {
      _showDenied(PermissionService.instance.denialReason('delete items'));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Pass storeId to prevent cross-store deletes
              final success = await InventoryService.instance.deleteItem(
                item.id,
                _storeId,
              );
              if (success && mounted) {
                setState(() => _items.removeWhere((i) => i.id == item.id));
                ActivityLogService.instance.log(
                  storeId: _storeId,
                  userId: _userId,
                  userName: _userName,
                  userRole: _userRole,
                  actionType: ActivityActionType.itemDeleted,
                  itemId: item.id,
                  itemName: item.name,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${item.name}" deleted')),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact bulk action button for Stock In / Stock Out
class _BulkActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _BulkActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
