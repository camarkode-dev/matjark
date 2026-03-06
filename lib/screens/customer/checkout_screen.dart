import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/payment_service.dart';

class CheckoutScreen extends StatefulWidget {
  final String customerId;
  final List<Map<String, dynamic>> cartItems;

  const CheckoutScreen({
    super.key,
    required this.customerId,
    required this.cartItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _paymentService = PaymentService();
  final _addressController = TextEditingController();
  final _discountController = TextEditingController();

  PaymentMethodType _selectedMethod = PaymentMethodType.cod;
  String _selectedGovernorate = 'cairo';
  bool _loadingTotals = false;
  bool _placingOrder = false;
  Map<String, dynamic>? _totals;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadTotals() async {
    setState(() => _loadingTotals = true);
    try {
      final itemsPayload = widget.cartItems
          .map(
            (e) => {
              'quantity': e['quantity'] ?? 1,
              'unitPrice': e['unitPrice'] ?? e['price'] ?? 0,
            },
          )
          .toList();
      final totals = await _paymentService.calculateOrderTotals(
        items: itemsPayload,
        governorate: _selectedGovernorate,
        discountCode: _discountController.text.trim().isEmpty
            ? null
            : _discountController.text.trim(),
      );
      if (mounted) setState(() => _totals = totals);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('checkout.failed_totals'.tr())));
      }
    } finally {
      if (mounted) setState(() => _loadingTotals = false);
    }
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('checkout.enter_address'.tr())));
      return;
    }
    if (_totals == null) return;

    setState(() => _placingOrder = true);
    try {
      final db = FirebaseFirestore.instance;
      final sellerIds = widget.cartItems
          .map((e) => e['sellerId'])
          .whereType<String>()
          .toSet()
          .toList();
      final supplierIds = widget.cartItems
          .map((e) => e['supplierId'])
          .whereType<String>()
          .toSet()
          .toList();
      final totalAmount = ((_totals!['totalAmount'] ?? 0) as num).toDouble();
      final platformFee = double.parse((totalAmount * 0.02).toStringAsFixed(2));
      final sellerRevenue = double.parse(
        (totalAmount - platformFee).toStringAsFixed(2),
      );

      final orderData = {
        'customerId': widget.customerId,
        'sellerId': sellerIds.isNotEmpty ? sellerIds.first : null,
        'supplierId': supplierIds.isNotEmpty ? supplierIds.first : null,
        'sellerIds': sellerIds,
        'supplierIds': supplierIds,
        'items': widget.cartItems,
        'status': 'pending',
        'address': _addressController.text.trim(),
        'governorate': _selectedGovernorate,
        'discountCode': _discountController.text.trim(),
        'paymentMethod': _selectedMethod.name,
        'payment_method': _selectedMethod.name,
        'payment_status': 'pending',
        'currency': 'EGP',
        'subtotalAmount': _totals!['subtotal'] ?? 0,
        'discountAmount': _totals!['discountAmount'] ?? 0,
        'taxAmount': _totals!['taxAmount'] ?? 0,
        'shippingAmount': _totals!['shippingAmount'] ?? 0,
        'totalAmount': totalAmount,
        'platform_fee': platformFee,
        'seller_revenue': sellerRevenue,
        'commission': platformFee,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final orderRef = await db.collection('orders').add(orderData);
      final payment = await _paymentService.processPayment(
        method: _selectedMethod,
        amount: (_totals!['totalAmount'] as num).toDouble(),
        orderId: orderRef.id,
        customerId: widget.customerId,
      );

      await orderRef.set({
        'paymentReferenceId': payment.referenceId,
        'payment_status': payment.status,
        'paymentStatus': payment.status,
        'paymentProvider': payment.provider,
        'paymentMessage': payment.message,
        'paymentMetadata': payment.metadata,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final cartItemsRef = db
          .collection('carts')
          .doc(widget.customerId)
          .collection('items');
      final cartSnapshot = await cartItemsRef.get();
      final batch = db.batch();
      for (final doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('checkout.payment_confirmation_title'.tr()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('checkout.placed_success'.tr()),
                  const SizedBox(height: 8),
                  Text(
                    'checkout.payment_reference'.tr(
                      namedArgs: {'id': payment.referenceId},
                    ),
                  ),
                  Text(
                    'checkout.payment_provider'.tr(
                      namedArgs: {'provider': payment.provider},
                    ),
                  ),
                  Text(
                    'checkout.payment_status'.tr(
                      namedArgs: {'status': payment.status},
                    ),
                  ),
                ],
              ),
              actions: [
                if ((payment.metadata['checkoutUrl'] ?? '')
                    .toString()
                    .isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(
                        (payment.metadata['checkoutUrl'] ?? '').toString(),
                      );
                      if (uri == null) return;
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text('checkout.open_payment_page'.tr()),
                  ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.submit'.tr()),
                ),
              ],
            );
          },
        );
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/customer/orders', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'checkout.failed'.tr(namedArgs: {'error': e.toString()}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final totalAmount = ((_totals?['totalAmount'] ?? 0) as num).toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFF090F1F),
      appBar: AppBar(title: Text('checkout.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D3B5C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr ? 'عنوان الشحن' : 'Shipping Address',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'checkout.delivery_address'.tr(),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D3B5C)),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedGovernorate,
                  decoration: InputDecoration(
                    labelText: 'checkout.governorate'.tr(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'cairo',
                      child: Text('governorates.cairo'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'giza',
                      child: Text('governorates.giza'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'alexandria',
                      child: Text('governorates.alexandria'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'delta',
                      child: Text('governorates.delta'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'upper_egypt',
                      child: Text('governorates.upper_egypt'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'sinai',
                      child: Text('governorates.sinai'.tr()),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedGovernorate = v);
                    _loadTotals();
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: 'checkout.discount_code'.tr(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: _loadTotals,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D3B5C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'checkout.payment_method'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentMethodType>(
                  initialValue: _selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'checkout.select_payment_method'.tr(),
                  ),
                  items: PaymentMethodType.values
                      .map(
                        (method) => DropdownMenuItem<PaymentMethodType>(
                          value: method,
                          child: Text(method.translationKey.tr()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedMethod = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D3B5C)),
            ),
            child: _loadingTotals
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'checkout.subtotal'.tr()}: ${(_totals?['subtotal'] ?? 0).toString()} ${'common.currency_egp'.tr()}',
                      ),
                      Text(
                        '${'checkout.discount'.tr()}: ${(_totals?['discountAmount'] ?? 0).toString()} ${'common.currency_egp'.tr()}',
                      ),
                      Text(
                        '${'checkout.tax'.tr()}: ${(_totals?['taxAmount'] ?? 0).toString()} ${'common.currency_egp'.tr()}',
                      ),
                      Text(
                        '${'checkout.shipping'.tr()}: ${(_totals?['shippingAmount'] ?? 0).toString()} ${'common.currency_egp'.tr()}',
                      ),
                      const Divider(),
                      Text(
                        '${'checkout.total'.tr()}: ${totalAmount.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: (_placingOrder || _loadingTotals) ? null : _placeOrder,
            icon: _placingOrder
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _placingOrder
                  ? 'checkout.placing_order'.tr()
                  : 'checkout.confirm_order'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}
