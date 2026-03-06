import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../screens/customer/product_details_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  Future<void> _toggleFavorite(BuildContext context, bool isFavorite) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.login_required'.tr())));
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(product.id);
    try {
      if (isFavorite) {
        await ref.delete();
      } else {
        await ref.set({
          'productId': product.id,
          'titleAr': product.titleAr,
          'titleEn': product.titleEn,
          'sellingPrice': product.sellingPrice,
          'price': product.sellingPrice,
          'imageUrl': product.images.isNotEmpty ? product.images.first : null,
          'sellerId': product.sellerId,
          'supplierId': product.supplierId,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? 'product.remove_from_favorites'.tr()
                : 'product.add_to_favorites'.tr(),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'product.favorite_failed'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final favoriteRef = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('favorites')
              .doc(product.id);
    final isArabic = context.locale.languageCode == 'ar';
    final productTitle = isArabic
        ? (product.titleAr.isNotEmpty ? product.titleAr : product.titleEn)
        : (product.titleEn.isNotEmpty ? product.titleEn : product.titleAr);
    final hasDiscount = product.costPrice > product.sellingPrice;
    final discountPercent = hasDiscount && product.costPrice > 0
        ? (((product.costPrice - product.sellingPrice) / product.costPrice) *
                  100)
              .round()
        : 0;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.panel(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusCard),
                    topRight: Radius.circular(AppTheme.radiusCard),
                  ),
                  color: AppTheme.scaffold(context),
                ),
                child: Stack(
                  children: [
                    product.images.isNotEmpty
                        ? Hero(
                            tag: 'product_image_${product.id}',
                            child: CachedNetworkImage(
                              imageUrl: product.images.first,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              fadeInDuration: const Duration(milliseconds: 120),
                              placeholder: (_, placeholderUrl) => Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.panelSoft(context),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusCard,
                                  ),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, imageUrl, error) => Icon(
                                Icons.broken_image_outlined,
                                color: AppTheme.secondaryText(context),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.panelSoft(context),
                                  AppTheme.panel(context),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppTheme.secondaryText(context),
                            ),
                          ),
                    if (hasDiscount)
                      PositionedDirectional(
                        top: AppTheme.spacing8,
                        start: AppTheme.spacing8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '-$discountPercent%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: AppTheme.spacing8,
                      right: AppTheme.spacing8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.panel(context),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.shadowSmall,
                        ),
                        child: favoriteRef == null
                            ? IconButton(
                                onPressed: () =>
                                    _toggleFavorite(context, false),
                                icon: const Icon(Icons.favorite_border),
                                color: AppTheme.error,
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              )
                            : StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: favoriteRef.snapshots(),
                                builder: (context, snapshot) {
                                  final isFavorite =
                                      snapshot.data?.exists ?? false;
                                  return IconButton(
                                    onPressed: () =>
                                        _toggleFavorite(context, isFavorite),
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                    color: AppTheme.error,
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 3),
                      Text(product.rating.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${product.sellingPrice.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (hasDiscount)
                        Text(
                          product.costPrice.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: AppTheme.secondaryText(context),
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
