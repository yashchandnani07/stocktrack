import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../services/activity_log_service.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../services/realtime_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';
import './widgets/add_category_sheet_widget.dart';
import './widgets/category_card_widget.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _userRole = 'Owner';
  String _userName = '';
  String _userId = '';
  String _storeId = '';
  String _storeName = '';
  bool _isLoading = true;
  List<CategoryModel> _categories = [];
  bool _realtimeSubscribed = false;

  @override
  void dispose() {
    RealtimeService.instance.unsubscribe('categories_$_storeId');
    super.dispose();
  }

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
      _userName = args['userName'] as String? ?? '';
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
        _loadCategories();
      }
    }
  }

  Future<void> _loadCategories() async {
    if (_storeId.isEmpty) return;
    // Unsubscribe existing realtime channel before re-subscribing
    if (_realtimeSubscribed) {
      RealtimeService.instance.unsubscribe('categories_$_storeId');
      _realtimeSubscribed = false;
    }
    setState(() => _isLoading = true);
    final cats = await InventoryService.instance.fetchCategories(_storeId);
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
      _subscribeRealtime();
    }
  }

  void _subscribeRealtime() {
    if (_realtimeSubscribed || _storeId.isEmpty) return;
    _realtimeSubscribed = true;

    RealtimeService.instance.subscribeToTable(
      channelName: 'categories_$_storeId',
      table: 'categories',
      storeId: _storeId,
      onInsert: (record) {
        if (!mounted) return;
        final newCat = CategoryModel.fromMap(record);
        setState(() {
          if (!_categories.any((c) => c.id == newCat.id)) {
            _categories.add(newCat);
          }
        });
      },
      onUpdate: (record) {
        if (!mounted) return;
        final updated = CategoryModel.fromMap(record);
        setState(() {
          final idx = _categories.indexWhere((c) => c.id == updated.id);
          if (idx != -1) {
            _categories[idx] = updated;
          }
        });
      },
      onDelete: (record) {
        if (!mounted) return;
        final deletedId = record['id'] as String?;
        if (deletedId != null) {
          setState(() => _categories.removeWhere((c) => c.id == deletedId));
        }
      },
    );
  }

  bool get _canManage => PermissionService.instance.canCreateCategory;
  bool get _canDelete => PermissionService.instance.canDeleteCategory;

  void _showAddSheet() {
    if (!_canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PermissionService.instance.denialReason('add categories'),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCategorySheet(
        onAdd: (name, color, icon) async {
          final cat = CategoryModel(
            id: '',
            storeId: _storeId,
            name: name,
            color: color,
            icon: icon,
            itemCount: 0,
          );
          final created = await InventoryService.instance.createCategory(cat);
          if (created != null && mounted) {
            setState(() => _categories.add(created));
            // Log category creation
            ActivityLogService.instance.log(
              storeId: _storeId,
              userId: _userId,
              userName: _userName,
              userRole: _userRole,
              actionType: ActivityActionType.categoryCreated,
              details: name,
            );
          }
        },
      ),
    );
  }

  void _deleteCategory(CategoryModel cat) {
    if (!PermissionService.instance.canPerformAnyAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PermissionService.instance.denialReason('delete categories'),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (!_canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PermissionService.instance.denialReason('delete categories'),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${cat.name}"? Items in this category will become uncategorised.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Pass storeId to prevent cross-store deletes
              final success = await InventoryService.instance.deleteCategory(
                cat.id,
                _storeId,
              );
              if (success && mounted) {
                setState(() => _categories.remove(cat));
                // Log category deletion
                ActivityLogService.instance.log(
                  storeId: _storeId,
                  userId: _userId,
                  userName: _userName,
                  userRole: _userRole,
                  actionType: ActivityActionType.categoryDeleted,
                  details: cat.name,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${cat.name}" deleted')),
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

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final crossAxisCount = isTablet ? 3 : 2;

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: AppNavigation(
        currentIndex: 1,
        userRole: _userRole,
        userName: _userName,
        userId: _userId,
        isActive: PermissionService.instance.isActive,
        storeId: _storeId,
        storeName: _storeName,
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
            )
          : null,
      body: isTablet
          ? Row(
              children: [
                AppNavigation(
                  currentIndex: 1,
                  userRole: _userRole,
                  userName: _userName,
                  userId: _userId,
                  isActive: PermissionService.instance.isActive,
                  storeId: _storeId,
                  storeName: _storeName,
                ),
                Expanded(child: _buildBody(crossAxisCount)),
              ],
            )
          : _buildBody(crossAxisCount),
    );
  }

  Widget _buildBody(int crossAxisCount) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categories',
                  style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _storeName.isNotEmpty
                      ? '$_storeName · ${_categories.length} categories'
                      : '${_categories.length} categories',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _categories.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    subtitle:
                        'Create categories to organise your inventory items by type.',
                    actionLabel: _canManage ? 'Add Category' : null,
                    onAction: _canManage ? _showAddSheet : null,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (_, i) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds: 240 + (i * 60).clamp(0, 360),
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) => Opacity(
                          opacity: v,
                          child: Transform.scale(
                            scale: 0.92 + 0.08 * v,
                            child: child,
                          ),
                        ),
                        child: CategoryCardWidget(
                          category: _categories[i],
                          canManage: _canManage,
                          canDelete: _canDelete,
                          onDelete: () => _deleteCategory(_categories[i]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
