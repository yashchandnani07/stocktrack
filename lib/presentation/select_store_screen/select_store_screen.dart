import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/store_service.dart';
import '../../services/permission_service.dart';
import '../../routes/app_routes.dart';

/// Shown when a user has multiple stores — lets them select or create a store
class SelectStoreScreen extends StatefulWidget {
  const SelectStoreScreen({super.key});

  @override
  State<SelectStoreScreen> createState() => _SelectStoreScreenState();
}

class _SelectStoreScreenState extends State<SelectStoreScreen>
    with SingleTickerProviderStateMixin {
  List<StoreModel> _stores = [];
  bool _isLoading = true;
  bool _isCreating = false;
  final _createFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _showCreateForm = false;

  String _userName = '';
  String _userId = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadStores();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _userName = args['userName'] as String? ?? '';
      _userId = args['userId'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final stores = await StoreService.instance.fetchMyStores();
    if (mounted) {
      setState(() {
        _stores = stores;
        _isLoading = false;
      });
      _animController.forward();
    }
  }

  Future<void> _selectStore(StoreModel store) async {
    final role = await StoreService.instance.getRoleInStore(store.id);
    StoreService.instance.setCurrentStore(store, role);

    // Fetch actual is_active status for this member from DB
    bool isActive = true;
    try {
      final client = StoreService.instance.client;
      final resp = await client
          .from('store_members')
          .select('is_active')
          .eq('store_id', store.id)
          .eq('user_id', _userId)
          .maybeSingle();
      if (resp != null) {
        isActive = resp['is_active'] as bool? ?? true;
      }
    } catch (_) {
      // If check fails, default to active — owner is always active
    }

    PermissionService.instance.setUser(
      role: role,
      userId: _userId,
      isActive: isActive,
      storeId: store.id, // ← was missing: needed for refreshActiveStatus()
    );

    if (!mounted) return;

    if (!isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account has been disabled. Contact the store owner.',
          ),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.inventoryScreen,
      arguments: {
        'role': role,
        'userName': _userName,
        'userId': _userId,
        'isActive': isActive,
        'storeId': store.id,
        'storeName': store.name,
      },
    );
  }

  Future<void> _createStore() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    final store = await StoreService.instance.createStore(
      _nameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create store.',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    _nameController.clear();
    setState(() => _showCreateForm = false);
    await _loadStores();
  }

  void _signOut() {
    Navigator.pushReplacementNamed(context, AppRoutes.signUpLoginScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : FadeTransition(opacity: _fadeAnim, child: _buildContent()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFF111113),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'StockTrack',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  _userName.isNotEmpty
                      ? 'Hello, ${_userName.split(' ').first}'
                      : 'Select a store',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: AppTheme.onSurfaceMuted,
            ),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Stores',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_stores.length} store${_stores.length == 1 ? '' : 's'} available',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 20),
          ..._stores.asMap().entries.map((entry) {
            final i = entry.key;
            final store = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 250 + (i * 60)),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - v)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StoreCard(
                  store: store,
                  onTap: () => _selectStore(store),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          if (_showCreateForm) _buildCreateForm() else _buildAddStoreButton(),
        ],
      ),
    );
  }

  Widget _buildAddStoreButton() {
    return GestureDetector(
      onTap: () => setState(() => _showCreateForm = true),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withAlpha(80), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Create New Store',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Store',
              style: GoogleFonts.fraunces(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppTheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Store Name',
                hintText: 'e.g. Branch 2, Warehouse B',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showCreateForm = false);
                      _nameController.clear();
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(color: AppTheme.onSurfaceMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: const Color(0xFF111113),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF111113),
                            ),
                          )
                        : Text(
                            'Create',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withAlpha(60)),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Tap to open',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.onSurfaceMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
