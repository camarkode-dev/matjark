import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _updatingCart = false;
  bool _updatingFavorite = false;
  final ValueNotifier<int> _currentImage = ValueNotifier<int>(0);

  Future<void> _addToCart() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.login_required'.tr())));
      return;
    }

    setState(() => _updatingCart = true);
    try {
      final product = widget.product;
      final cartItemRef = FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .doc(product.id);

      await cartItemRef.set({
        'productId': product.id,
        'titleAr': product.titleAr,
        'titleEn': product.titleEn,
        'unitPrice': product.sellingPrice,
        'price': product.sellingPrice,
        'sellerId': product.sellerId,
        'supplierId': product.supplierId,
        'imageUrl': product.images.isNotEmpty ? product.images.first : null,
        'quantity': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('product.added_to_cart'.tr())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'product.add_to_cart_failed'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingCart = false);
    }
  }

  Future<void> _toggleFavorite(bool isFavorite) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.login_required'.tr())));
      return;
    }

    setState(() => _updatingFavorite = true);
    try {
      final product = widget.product;
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(product.id);

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'product.favorite_failed'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingFavorite = false);
    }
  }

  @override
  void dispose() {
    _currentImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isArabic = context.locale.languageCode == 'ar';
    final title = isArabic
        ? (product.titleAr.isNotEmpty ? product.titleAr : product.titleEn)
        : (product.titleEn.isNotEmpty ? product.titleEn : product.titleAr);
    final description = isArabic
        ? (product.descriptionAr.isNotEmpty
              ? product.descriptionAr
              : product.descriptionEn)
        : (product.descriptionEn.isNotEmpty
              ? product.descriptionEn
              : product.descriptionAr);

    final hasDiscount = product.costPrice > product.sellingPrice;
    final discountPercent = hasDiscount && product.costPrice > 0
        ? (((product.costPrice - product.sellingPrice) / product.costPrice) *
                  100)
              .round()
        : 0;

    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.uid;
    final favoriteRef = userId == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .doc(product.id);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('product.details'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
        children: [
          Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
              color: AppTheme.surface,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PageView.builder(
                    itemCount: product.images.isEmpty
                        ? 1
                        : product.images.length,
                    onPageChanged: (value) => _currentImage.value = value,
                    itemBuilder: (context, index) {
                      if (product.images.isEmpty) {
                        return const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xFF1A2440)),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 42,
                          ),
                        );
                      }
                      return Hero(
                        tag: index == 0
                            ? 'product_image_${product.id}'
                            : 'product_image_${product.id}_$index',
                        child: CachedNetworkImage(
                          imageUrl: product.images[index],
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      );
                    },
                  ),
                ),
                if (hasDiscount)
                  PositionedDirectional(
                    start: 10,
                    top: 10,
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
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: _currentImage,
            builder: (context, value, _) {
              final count = product.images.isEmpty ? 1 : product.images.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == value ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: index == value
                          ? AppTheme.primary
                          : AppTheme.borderLight,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${product.sellingPrice.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (hasDiscount)
                      Text(
                        '${product.costPrice.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                    const SizedBox(width: 4),
                    Text(product.rating.toStringAsFixed(1)),
                    const SizedBox(width: 10),
                    Icon(
                      product.stock > 0
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 18,
                      color: product.stock > 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.stock > 0
                            ? 'product.in_stock'.tr(
                                namedArgs: {'count': product.stock.toString()},
                              )
                            : 'product.out_of_stock'.tr(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'product.description'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  description.trim().isEmpty
                      ? 'product.no_description'.tr()
                      : description,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'product.reviews'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .doc(product.id)
                      .collection('reviews')
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Text('product.no_reviews'.tr());
                    }
                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data();
                        final reviewer =
                            (data['userName'] ?? 'common.user'.tr()).toString();
                        final rating = ((data['rating'] ?? 0) as num)
                            .toDouble();
                        final comment = (data['comment'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reviewer,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (comment.trim().isNotEmpty)
                                      Text(comment),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(rating.toStringAsFixed(1)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.borderLight)),
          ),
          child: Row(
            children: [
              if (favoriteRef != null)
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: favoriteRef.snapshots(),
                    builder: (context, snapshot) {
                      final isFavorite = snapshot.data?.exists ?? false;
                      return OutlinedButton.icon(
                        onPressed: _updatingFavorite
                            ? null
                            : () => _toggleFavorite(isFavorite),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.redAccent,
                        ),
                        label: Text(
                          isFavorite
                              ? (isArabic ? 'إزالة' : 'Remove')
                              : (isArabic ? 'مفضلة' : 'Favorite'),
                        ),
                      );
                    },
                  ),
                ),
              if (favoriteRef != null) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_updatingCart || product.stock <= 0)
                      ? null
                      : _addToCart,
                  icon: _updatingCart
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    product.stock > 0
                        ? 'product.add_to_cart'.tr()
                        : 'product.out_of_stock'.tr(),
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
