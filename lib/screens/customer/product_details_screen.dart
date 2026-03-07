import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/remote_image.dart';
import 'checkout_screen.dart';

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

  Product get _product => widget.product;

  String _title(bool isArabic) {
    return isArabic
        ? (_product.titleAr.isNotEmpty ? _product.titleAr : _product.titleEn)
        : (_product.titleEn.isNotEmpty ? _product.titleEn : _product.titleAr);
  }

  String _description(bool isArabic) {
    return isArabic
        ? (_product.descriptionAr.isNotEmpty
            ? _product.descriptionAr
            : _product.descriptionEn)
        : (_product.descriptionEn.isNotEmpty
            ? _product.descriptionEn
            : _product.descriptionAr);
  }

  bool get _hasDiscount => _product.costPrice > _product.sellingPrice;

  int get _discountPercent {
    if (!_hasDiscount || _product.costPrice <= 0) {
      return 0;
    }
    return (((_product.costPrice - _product.sellingPrice) /
                _product.costPrice) *
            100)
        .round();
  }

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
      final cartItemRef = FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .doc(_product.id);

      await cartItemRef.set({
        'productId': _product.id,
        'titleAr': _product.titleAr,
        'titleEn': _product.titleEn,
        'unitPrice': _product.sellingPrice,
        'price': _product.sellingPrice,
        'sellerId': _product.sellerId,
        'vendorId': _product.sellerId,
        'supplierId': _product.supplierId,
        'imageUrl': _product.images.isNotEmpty ? _product.images.first : null,
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
      if (mounted) {
        setState(() => _updatingCart = false);
      }
    }
  }

  Future<void> _buyNow() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('common.login_required'.tr())));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          customerId: user.uid,
          cartItems: [
            {
              'productId': _product.id,
              'titleAr': _product.titleAr,
              'titleEn': _product.titleEn,
              'unitPrice': _product.sellingPrice,
              'price': _product.sellingPrice,
              'sellerId': _product.sellerId,
              'vendorId': _product.sellerId,
              'supplierId': _product.supplierId,
              'imageUrl':
                  _product.images.isNotEmpty ? _product.images.first : null,
              'quantity': 1,
            },
          ],
        ),
      ),
    );
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
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(_product.id);

      if (isFavorite) {
        await ref.delete();
      } else {
        await ref.set({
          'productId': _product.id,
          'titleAr': _product.titleAr,
          'titleEn': _product.titleEn,
          'sellingPrice': _product.sellingPrice,
          'price': _product.sellingPrice,
          'imageUrl': _product.images.isNotEmpty ? _product.images.first : null,
          'sellerId': _product.sellerId,
          'supplierId': _product.supplierId,
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
      if (mounted) {
        setState(() => _updatingFavorite = false);
      }
    }
  }

  Widget _buildPanel({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: child,
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final title = _title(isArabic);
    final description = _description(isArabic).trim();
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.uid;
    final favoriteRef = userId == null
        ? null
        : FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(_product.id);

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(),
        title: Text('product.details'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 132),
        children: [
          _buildPanel(
            context: context,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SizedBox(
                  height: 320,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PageView.builder(
                          itemCount: _product.images.isEmpty
                              ? 1
                              : _product.images.length,
                          onPageChanged: (value) => _currentImage.value = value,
                          itemBuilder: (context, index) {
                            if (_product.images.isEmpty) {
                              return Container(
                                color: AppTheme.panelSoft(context),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 42,
                                ),
                              );
                            }
                            return Hero(
                              tag: index == 0
                                  ? 'product_image_${_product.id}'
                                  : 'product_image_${_product.id}_$index',
                              child: RemoteImage(
                                imageUrl: _product.images[index],
                                fit: BoxFit.cover,
                                placeholder: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: const Icon(
                                  Icons.broken_image_outlined,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_hasDiscount)
                        PositionedDirectional(
                          start: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '-$_discountPercent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_product.images.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 62,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentImage,
                      builder: (context, activeIndex, _) {
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _product.images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final isActive = index == activeIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 62,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.border(context),
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: RemoteImage(
                                  imageUrl: _product.images[index],
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                    color: AppTheme.panelSoft(context),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPanel(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_product.sellingPrice.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(width: 8),
                    if (_hasDiscount)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${_product.costPrice.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: AppTheme.secondaryText(context),
                                  ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeatureChip(
                      context,
                      Icons.star_rounded,
                      '${_product.rating.toStringAsFixed(1)} / 5',
                    ),
                    _buildFeatureChip(
                      context,
                      _product.stock > 0
                          ? Icons.inventory_2_outlined
                          : Icons.remove_shopping_cart_outlined,
                      _product.stock > 0
                          ? 'product.in_stock'.tr(
                              namedArgs: {'count': _product.stock.toString()},
                            )
                          : 'product.out_of_stock'.tr(),
                    ),
                    _buildFeatureChip(
                      context,
                      Icons.local_shipping_outlined,
                      isArabic ? 'شحن سريع' : 'Fast shipping',
                    ),
                    _buildFeatureChip(
                      context,
                      Icons.assignment_return_outlined,
                      isArabic ? 'إرجاع مرن' : 'Easy returns',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPanel(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'product.description'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description.isEmpty
                      ? 'product.no_description'.tr()
                      : description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPanel(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'مزايا الشراء' : 'Why buy this item',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                _DetailBullet(
                  icon: Icons.shield_outlined,
                  text: isArabic
                      ? 'دفع آمن وتتبع واضح لحالة الطلب.'
                      : 'Secure payment with clear order tracking.',
                ),
                _DetailBullet(
                  icon: Icons.sell_outlined,
                  text: isArabic
                      ? 'سعر واضح مع عرض الخصم عند توفره.'
                      : 'Transparent pricing with discount visibility.',
                ),
                _DetailBullet(
                  icon: Icons.support_agent_outlined,
                  text: isArabic
                      ? 'يمكنك طلب الإرجاع بعد التسليم حسب حالة الطلب.'
                      : 'Return requests are available after delivery when eligible.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPanel(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'product.reviews'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .doc(_product.id)
                      .collection('reviews')
                      .orderBy('createdAt', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                          '${'errors.network'.tr()}: ${snapshot.error}');
                    }
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
                        final ratingValue = data['rating'];
                        final rating = ratingValue is num
                            ? ratingValue.toDouble()
                            : double.tryParse('$ratingValue') ?? 0;
                        final comment = (data['comment'] ?? '').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.panelSoft(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppTheme.primary.withValues(alpha: 0.16),
                                child: Text(
                                  reviewer.isEmpty
                                      ? 'U'
                                      : reviewer.characters.first.toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            reviewer,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber.shade700,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(rating.toStringAsFixed(1)),
                                      ],
                                    ),
                                    if (comment.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(comment),
                                    ],
                                  ],
                                ),
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
          decoration: BoxDecoration(
            color: AppTheme.panel(context),
            border: Border(top: BorderSide(color: AppTheme.border(context))),
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
                child: OutlinedButton.icon(
                  onPressed: _product.stock > 0 ? _buyNow : null,
                  icon: const Icon(Icons.bolt_outlined),
                  label: Text(isArabic ? 'اشتر الآن' : 'Buy now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_updatingCart || _product.stock <= 0)
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
                    _product.stock > 0
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

class _DetailBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailBullet({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
