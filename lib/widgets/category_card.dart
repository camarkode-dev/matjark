import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../core/theme.dart';
import '../models/category.dart';
import 'remote_image.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;
  const CategoryCard({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final categoryName = isArabic
        ? (category.nameAr.isNotEmpty ? category.nameAr : category.nameEn)
        : (category.nameEn.isNotEmpty ? category.nameEn : category.nameAr);

    return SizedBox(
      width: 120,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.panel(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusCard),
                    topRight: Radius.circular(AppTheme.radiusCard),
                  ),
                  child: category.imageUrl != null
                      ? RemoteImage(
                          imageUrl: category.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: _fallbackIcon(),
                        )
                      : _fallbackIcon(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                child: Text(
                  categoryName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.16),
            AppTheme.secondary.withValues(alpha: 0.16),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.category_outlined, size: 44, color: AppTheme.primary),
      ),
    );
  }
}
