import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/inventory_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_widget.dart';

class AddEditItemScreen extends StatefulWidget {
  const AddEditItemScreen({super.key});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _thresholdController = TextEditingController();

  String _selectedCategory = '';
  String _selectedUnit = 'pcs';
  bool _isLoading = false;
  bool _isEdit = false;
  InventoryItem? _editItem;
  List<String> _categories = [];
  String _userRole = 'Owner';
  String _userName = 'User';
  String _userId = '';
  String _storeId = '';
  Function? _onDeleteCallback;

  final List<String> _units = [
    'pcs',
    'kg',
    'g',
    'L',
    'mL',
    'boxes',
    'reams',
    'sets',
    'bottles',
    'bags',
    'pairs',
    'rolls',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _userRole = args['role'] as String? ?? 'Manager';
      _userName = args['userName'] as String? ?? 'User';
      _userId = args['userId'] as String? ?? '';
      _storeId = args['storeId'] as String? ?? '';
      _categories = List<String>.from(
        args['categories'] as List? ?? ['Electronics', 'Stationery'],
      );
      if (_categories.isEmpty) _categories = ['General'];
      _onDeleteCallback = args['onDelete'] as Function?;

      final item = args['item'] as InventoryItem?;
      if (item != null && !_isEdit) {
        _isEdit = true;
        _editItem = item;
        _nameController.text = item.name;
        _quantityController.text = formatQuantity(item.quantity);
        _barcodeController.text = item.barcode ?? '';
        _thresholdController.text = item.lowStockThreshold.toString();
        _selectedCategory = item.category;
        _selectedUnit = item.unit;
      } else if (!_isEdit && _selectedCategory.isEmpty) {
        _selectedCategory = _categories.first;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _barcodeController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  bool get _canEdit =>
      PermissionService.instance.canEditItem ||
      PermissionService.instance.canCreateItem;
  bool get _canDelete => PermissionService.instance.canDeleteItem && _isEdit;

  void _handleSave() async {
    // Logic-level permission check — re-verify on every save attempt
    if (!PermissionService.instance.canPerformAnyAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PermissionService.instance.denialReason('save items')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PermissionService.instance.denialReason('save items')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final newItem = InventoryItem(
      id: _editItem?.id ?? '',
      storeId: _storeId,
      name: _nameController.text.trim(),
      category: _selectedCategory,
      quantity: (double.tryParse(_quantityController.text) ?? 0.0).clamp(
        0,
        kMaxQuantity,
      ),
      lowStockThreshold: (int.tryParse(_thresholdController.text) ?? 5).clamp(
        0,
        kMaxThreshold,
      ),
      unit: _selectedUnit,
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      lastUpdated: DateTime.now(),
      updatedBy: _userName,
    );

    InventoryItem? saved;
    if (_isEdit && _editItem != null) {
      saved = await InventoryService.instance.updateItem(newItem.copyWith());
      saved ??= newItem;
    } else {
      saved = await InventoryService.instance.createItem(newItem);
      saved ??= newItem;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args?['onSave'] is Function) {
        (args!['onSave'] as Function)(saved);
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Item updated successfully' : 'Item added successfully',
          ),
        ),
      );
    }
  }

  void _handleDelete() {
    // Logic-level permission check — re-verify on every delete attempt
    if (!PermissionService.instance.canPerformAnyAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PermissionService.instance.denialReason('delete items'),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (!PermissionService.instance.canDeleteItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PermissionService.instance.denialReason('delete items'),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Delete "${_editItem?.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              if (_onDeleteCallback != null && _editItem != null) {
                _onDeleteCallback!(_editItem!.id);
              }
              Navigator.pop(context); // close screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${_editItem?.name}" deleted')),
              );
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: StockTrackAppBar(
        title: _isEdit ? 'Edit Item' : 'Add Item',
        showBack: true,
        actions: [
          if (_canDelete)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error,
                size: 20,
              ),
              onPressed: _handleDelete,
              tooltip: 'Delete Item',
            ),
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_canEdit) _buildReadOnlyBanner(),
            _buildBasicInfoSection(),
            const SizedBox(height: 16),
            _buildStockSection(),
            const SizedBox(height: 16),
            _buildOptionalSection(),
            const SizedBox(height: 24),
            if (_canEdit) _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: 680,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (!_canEdit) _buildReadOnlyBanner(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildBasicInfoSection()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStockSection()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildOptionalSection(),
                const SizedBox(height: 24),
                if (_canEdit) _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'View only — Staff cannot edit items.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard('ITEM DETAILS', [
      _buildUnderlineField(
        controller: _nameController,
        label: 'Item Name',
        hint: 'e.g. Wireless Keyboard MK450',
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Item name is required';
          if (v.trim().length < 2) return 'Name must be at least 2 characters';
          if (v.trim().length > kMaxItemNameLength) {
            return 'Name must be $kMaxItemNameLength characters or less';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      _buildCategoryDropdown(),
    ]);
  }

  Widget _buildStockSection() {
    return _buildSectionCard('STOCK SETTINGS', [
      Row(
        children: [
          Expanded(
            child: _buildUnderlineField(
              controller: _quantityController,
              label: _isEdit ? 'Current Quantity' : 'Initial Quantity',
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = double.tryParse(v);
                if (n == null) return 'Must be a valid number';
                if (n > kMaxQuantity) return 'Must be ≤ $kMaxQuantity';
                return null;
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _buildUnitDropdown()),
        ],
      ),
      const SizedBox(height: 20),
      _buildUnderlineField(
        controller: _thresholdController,
        label: 'Low Stock Alert Threshold',
        hint: '5',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          if (v != null && v.isNotEmpty) {
            final n = int.tryParse(v);
            if (n == null || n < 0) return 'Must be ≥ 0';
            if (n > kMaxThreshold) return 'Must be ≤ $kMaxThreshold';
          }
          return null;
        },
      ),
    ]);
  }

  Widget _buildOptionalSection() {
    return _buildSectionCard('OPTIONAL', [
      _buildUnderlineField(
        controller: _barcodeController,
        label: 'Barcode (optional)',
        hint: 'e.g. 8901234567890',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ]);
  }

  Widget _buildUnderlineField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      enabled: _canEdit,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppTheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSans(
          fontSize: 14,
          color: AppTheme.onSurfaceMuted,
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory.isEmpty ? null : _selectedCategory,
              isExpanded: true,
              hint: Text(
                'Select category',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.onSurfaceMuted,
                size: 20,
              ),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.onSurface,
              ),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _canEdit
                  ? (v) => setState(() => _selectedCategory = v!)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unit',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedUnit,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.onSurfaceMuted,
                size: 20,
              ),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.onSurface,
              ),
              items: _units
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(
                        u,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _canEdit
                  ? (v) => setState(() => _selectedUnit = v!)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleSave,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
        label: Text(_isEdit ? 'Save Changes' : 'Add Item'),
      ),
    );
  }
}
