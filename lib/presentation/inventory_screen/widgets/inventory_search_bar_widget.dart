import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class InventorySearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const InventorySearchBarWidget({super.key, required this.onChanged});

  @override
  State<InventorySearchBarWidget> createState() =>
      _InventorySearchBarWidgetState();
}

class _InventorySearchBarWidgetState extends State<InventorySearchBarWidget> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppTheme.onSurfaceMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: (v) {
                  widget.onChanged(v);
                  setState(() => _hasText = v.isNotEmpty);
                },
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or barcode…',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppTheme.onSurfaceMuted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  filled: false,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _hasText ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppTheme.onSurfaceMuted,
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() => _hasText = false);
                },
                splashRadius: 16,
              ),
            ),
            if (!_hasText) const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}
