import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';
import '../../widgets/remote_image.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Set<String> _updatingItems = <String>{};

  Future<void> _changeQuantity(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int delta,
  ) async {
    if (_updatingItems.contains(doc.id)) return;
    setState(() => _updatingItems.add(doc.id));

    try {
      final currentQty = ((doc.data()['quantity'] ?? 1) as num).toInt();
      final nextQty = currentQty + delta;
      if (nextQty <= 0) {
        await doc.reference.delete();
      } else {
        await doc.reference.set({
          'quantity': nextQty,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cart.update_failed'.tr(namedArgs: {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingItems.remove(doc.id));
    }
  }

  Future<void> _removeItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (_updatingItems.contains(doc.id)) return;
    setState(() => _updatingItems.add(doc.id));
    try {
      await doc.reference.delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cart.remove_failed'.tr(namedArgs: {'error': '$e'})),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingItems.remove(doc.id));
    }
  }

  String _title(Map<String, dynamic> data, bool isArabic) {
    return (isArabic
            ? (data['titleAr'] ?? data['titleEn'])
            : (data['titleEn'] ?? data['titleAr'])) ??
        data['title'] ??
        data['name'] ??
        'common.item'.tr().toString();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isArabic = context.locale.languageCode == 'ar';
    final itemsStream = FirebaseFirestore.instance
        .collection('carts')
        .doc(user.uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      drawer: const MarketplaceDrawer(),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('nav.cart'.tr()),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: itemsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${'errors.network'.tr()}: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text('cart.empty'.tr()),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/customer/categories'),
                    child: Text(isArabic ? 'ابدأ التسوق' : 'Start shopping'),
                  ),
                ],
              ),
            );
          }

          double subtotal = 0;
          for (final doc in docs) {
            final data = doc.data();
            final qty = (data['quantity'] ?? 0) as num;
            final price = (data['unitPrice'] ?? data['price'] ?? 0) as num;
            subtotal += qty.toDouble() * price.toDouble();
          }
          final shipping = subtotal >= 200 ? 0.0 : 15.0;
          final total = subtotal + shipping;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = _title(data, isArabic);
                    final qty = ((data['quantity'] ?? 1) as num).toInt();
                    final price =
                        ((data['unitPrice'] ?? data['price'] ?? 0) as num)
                            .toDouble();
                    final image = (data['imageUrl'] ?? '').toString();
                    final busy = _updatingItems.contains(doc.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.panel(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border(context)),
                        boxShadow: AppTheme.shadowSmall,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 70,
                              height: 70,
                              color: AppTheme.panelSoft(context),
                              child: image.isEmpty
                                  ? const Icon(Icons.inventory_2_outlined)
                                  : RemoteImage(
                                      imageUrl: image,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${price.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                if (busy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      _QtyButton(
                                        icon: Icons.remove,
                                        onPressed: () =>
                                            _changeQuantity(doc, -1),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _QtyButton(
                                        icon: Icons.add,
                                        onPressed: () =>
                                            _changeQuantity(doc, 1),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: () => _removeItem(doc),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: AppTheme.panel(context),
                    border: Border(
                      top: BorderSide(color: AppTheme.border(context)),
                    ),
                  ),
                  child: Column(
                    children: [
                      _TotalRow(
                        label: isArabic ? 'الإجمالي الفرعي' : 'Subtotal',
                        value:
                            '${subtotal.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                      ),
                      const SizedBox(height: 4),
                      _TotalRow(
                        label: isArabic ? 'الشحن' : 'Shipping',
                        value:
                            '${shipping.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                      ),
                      const Divider(height: 16),
                      _TotalRow(
                        label: isArabic ? 'الإجمالي' : 'Total',
                        value:
                            '${total.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        isStrong: true,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          final cartItems = docs
                              .map(
                                (itemDoc) => <String, dynamic>{
                                  ...itemDoc.data(),
                                  'cartItemId': itemDoc.id,
                                },
                              )
                              .toList();

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                customerId: user.uid,
                                cartItems: cartItems,
                              ),
                            ),
                          );
                        },
                        child: Text('cart.checkout'.tr()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QtyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTheme.panelSoft(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isStrong;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isStrong
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
