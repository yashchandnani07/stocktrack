import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class AddCategorySheet extends StatefulWidget {
  final Function(String name, Color color, IconData icon) onAdd;

  const AddCategorySheet({super.key, required this.onAdd});

  @override
  State<AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<AddCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Color _selectedColor = AppTheme.primary;
  IconData _selectedIcon = Icons.inventory_2_rounded;

  final List<Color> _colors = [
    AppTheme.primary,
    AppTheme.secondary,
    AppTheme.warning,
    AppTheme.accentPurple,
    AppTheme.accentBlue,
    AppTheme.error,
    const Color(0xFF1098AD),
    const Color(0xFFD6336C),
  ];

  final List<IconData> _icons = [
    Icons.inventory_2_rounded,
    Icons.devices_rounded,
    Icons.edit_rounded,
    Icons.chair_rounded,
    Icons.sanitizer_rounded,
    Icons.local_dining_rounded,
    Icons.build_rounded,
    Icons.medical_services_rounded,
    Icons.checkroom_rounded,
    Icons.sports_soccer_rounded,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'New Category',
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Category name is required';
                }
                return null;
              },
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppTheme.onSurface,
              ),
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 20),
            Text(
              'COLOUR',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurfaceMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: _colors.map((c) {
                final isSelected = _selectedColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppTheme.onSurface, width: 2.5)
                          : Border.all(color: c.withAlpha(80)),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'ICON',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurfaceMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withAlpha(22)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? _selectedColor : AppTheme.outline,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? _selectedColor
                          : AppTheme.onSurfaceMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onAdd(
                      _nameController.text.trim(),
                      _selectedColor,
                      _selectedIcon,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add Category'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
