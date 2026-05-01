import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/inventory_service.dart';

class CategoryCardWidget extends StatelessWidget {
  final CategoryModel category;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onDelete;

  const CategoryCardWidget({
    super.key,
    required this.category,
    required this.canManage,
    required this.onDelete,
    this.canDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      child: InkWell(
        onLongPress: canDelete ? onDelete : null,
        borderRadius: BorderRadius.circular(16),
        splashColor: category.color.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: category.color.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: category.color.withAlpha(60)),
                    ),
                    child: Icon(category.icon, size: 22, color: category.color),
                  ),
                  if (canDelete)
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: AppTheme.error,
                        ),
                      ),
                    )
                  else if (canManage)
                    const Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: AppTheme.onSurfaceMuted,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                category.name,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: category.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${category.itemCount} item${category.itemCount != 1 ? 's' : ''}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: category.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
