import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../services/media_upload_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/remote_image.dart';

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
  final _mediaUploadService = MediaUploadService();
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();
  final _paymentSenderController = TextEditingController();

  PaymentMethodType _selectedMethod = PaymentMethodType.cod;
  String _selectedGovernorate = 'cairo';
  bool _loadingTotals = false;
  bool _placingOrder = false;
  bool _uploadingReceipt = false;
  bool _discountVerified = false;
  String? _verifiedDiscountCode;
  String? _paymentReceiptUrl;
  Map<String, dynamic>? _totals;

  List<Map<String, dynamic>> get _quoteLines => widget.cartItems
      .map(
        (item) => <String, dynamic>{
          'productId': item['productId'],
          'quantity': item['quantity'] ?? 1,
        },
      )
      .where((item) => (item['productId'] ?? '').toString().isNotEmpty)
      .toList();

  bool get _hasMultipleVendors {
    final vendorIds = widget.cartItems
        .map((item) => (item['vendorId'] ?? item['sellerId'] ?? '').toString())
        .where((value) => value.isNotEmpty)
        .toSet();
    return vendorIds.length > 1;
  }

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_handleDiscountInputChanged);
    _loadTotals();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _paymentSenderController.dispose();
    super.dispose();
  }

  String _titleFor(Map<String, dynamic> item, bool isArabic) {
    return (isArabic
                ? (item['titleAr'] ?? item['titleEn'])
                : (item['titleEn'] ?? item['titleAr']))
            ?.toString() ??
        (item['name'] ?? item['title'] ?? 'common.item'.tr()).toString();
  }

  String _paymentLabel(PaymentMethodType method, bool isArabic) {
    switch (method) {
      case PaymentMethodType.card:
        return isArabic ? 'بطاقة بنكية' : 'Bank card';
      case PaymentMethodType.applePay:
        return 'Apple Pay';
      case PaymentMethodType.instapay:
        return 'InstaPay';
      case PaymentMethodType.bankTransfer:
        return isArabic ? 'تحويل بنكي' : 'Bank transfer';
      case PaymentMethodType.cod:
        return isArabic ? 'الدفع عند الاستلام' : 'Cash on delivery';
      case PaymentMethodType.fawry:
        return 'Fawry';
    }
  }

  IconData _paymentIcon(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.card:
        return Icons.credit_card_rounded;
      case PaymentMethodType.applePay:
        return Icons.phone_iphone_rounded;
      case PaymentMethodType.instapay:
        return Icons.flash_on_rounded;
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance_rounded;
      case PaymentMethodType.cod:
        return Icons.local_shipping_outlined;
      case PaymentMethodType.fawry:
        return Icons.qr_code_2_rounded;
    }
  }

  Map<String, String> _paymentInstructions(bool isArabic) {
    return switch (_selectedMethod) {
      PaymentMethodType.instapay => {
          'title': isArabic ? 'تحويل InstaPay' : 'InstaPay transfer',
          'body': isArabic
              ? 'حوّل على الرقم 01090886364 ثم أرفق صورة إيصال الدفع لتأكيد الطلب بسرعة.'
              : 'Transfer to 01090886364, then upload the payment receipt image for faster confirmation.',
          'primary': '01090886364',
          'secondary': isArabic ? 'اسم الحساب: Matjark Demo' : 'Account name: Matjark Demo',
        },
      PaymentMethodType.bankTransfer => {
          'title': isArabic ? 'بيانات التحويل البنكي' : 'Bank transfer details',
          'body': isArabic
              ? 'استخدم البيانات التجريبية التالية لحين إضافة بيانات البنك الفعلية.'
              : 'Use the following placeholder bank details until the live account is added.',
          'primary': 'EG38001900050000001002003004',
          'secondary': isArabic
              ? 'National Bank of Egypt • A/C 1002003004'
              : 'National Bank of Egypt • A/C 1002003004',
        },
      PaymentMethodType.fawry => {
          'title': isArabic ? 'كود فوري' : 'Fawry code',
          'body': isArabic
              ? 'استخدم الكود التجريبي التالي ثم أضف رقم العملية في المرجع.'
              : 'Use the following demo code and add the transaction reference.',
          'primary': '77889911',
          'secondary': isArabic ? 'رقم خدمة مؤقت: 01000000001' : 'Temporary service phone: 01000000001',
        },
      PaymentMethodType.cod => {
          'title': isArabic ? 'الدفع عند الاستلام' : 'Cash on delivery',
          'body': isArabic
              ? 'ادفع نقداً عند استلام الطلب. لا تحتاج إلى رفع إيصال.'
              : 'Pay in cash when the order arrives. No payment receipt is required.',
          'primary': isArabic ? 'الدفع عند التسليم' : 'Pay on arrival',
          'secondary': isArabic ? 'ستتواصل خدمة العملاء قبل الشحن.' : 'Support will confirm before shipping.',
        },
      PaymentMethodType.applePay => {
          'title': 'Apple Pay',
          'body': isArabic
              ? 'متاح على أجهزة Apple والمتصفحات المدعومة.'
              : 'Available on supported Apple devices and browsers.',
          'primary': isArabic ? 'دفع سريع وآمن' : 'Fast and secure checkout',
          'secondary': isArabic ? 'سيتم ربطه ببوابة الدفع لاحقاً.' : 'Gateway connection can be updated later.',
        },
      PaymentMethodType.card => {
          'title': isArabic ? 'الدفع بالبطاقة' : 'Card payment',
          'body': isArabic
              ? 'بطاقات Visa وMastercard مدعومة. سيتم ربط البوابة النهائية لاحقاً.'
              : 'Visa and Mastercard are supported. The live payment gateway can be connected later.',
          'primary': isArabic ? 'Visa / Mastercard' : 'Visa / Mastercard',
          'secondary': isArabic ? 'دفع آمن ومباشر' : 'Secure online payment',
        },
    };
  }

  bool get _requiresReceipt =>
      _selectedMethod == PaymentMethodType.instapay ||
      _selectedMethod == PaymentMethodType.bankTransfer ||
      _selectedMethod == PaymentMethodType.fawry;

  void _handleDiscountInputChanged() {
    final currentCode = _discountController.text.trim().toUpperCase();
    if (_verifiedDiscountCode == null || currentCode == _verifiedDiscountCode) {
      return;
    }
    if (_discountVerified || _verifiedDiscountCode != null) {
      setState(() {
        _discountVerified = false;
        _verifiedDiscountCode = null;
      });
    }
  }

  Future<void> _loadTotals({bool verifyDiscount = false}) async {
    if (_quoteLines.isEmpty) {
      setState(() {
        _totals = null;
        if (verifyDiscount) {
          _discountVerified = false;
          _verifiedDiscountCode = null;
        }
      });
      return;
    }

    setState(() => _loadingTotals = true);
    try {
      final inputCode = _discountController.text.trim().toUpperCase();
      final totals = await _paymentService.calculateOrderTotals(
        items: _quoteLines,
        governorate: _selectedGovernorate,
        discountCode: inputCode.isEmpty ? null : inputCode,
      );
      if (mounted) {
        final appliedCode =
            (totals['couponCode'] ?? '').toString().toUpperCase();
        setState(() {
          _totals = totals;
          if (verifyDiscount) {
            _discountVerified =
                inputCode.isNotEmpty && appliedCode == inputCode;
            _verifiedDiscountCode = _discountVerified ? appliedCode : null;
          } else if (_verifiedDiscountCode != null &&
              appliedCode != _verifiedDiscountCode) {
            _discountVerified = false;
            _verifiedDiscountCode = null;
          }
        });
        if (verifyDiscount) {
          final message = _discountVerified
              ? (context.locale.languageCode == 'ar'
                  ? 'تم التحقق من كود الخصم بنجاح.'
                  : 'Discount code verified successfully.')
              : (context.locale.languageCode == 'ar'
                  ? 'كود الخصم غير صالح أو غير متاح حالياً.'
                  : 'The discount code is invalid or unavailable.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (verifyDiscount) {
          setState(() {
            _discountVerified = false;
            _verifiedDiscountCode = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('checkout.failed_totals'.tr())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingTotals = false);
      }
    }
  }

  bool _validateCheckoutForm() {
    if (_quoteLines.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('cart.empty'.tr())));
      return false;
    }
    if (_hasMultipleVendors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'السلة تحتوي على أكثر من بائع. أكمل كل طلب بشكل منفصل.'
                : 'This cart contains multiple vendors. Complete each vendor order separately.',
          ),
        ),
      );
      return false;
    }
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    if (_totals == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('checkout.failed_totals'.tr())),
      );
      return false;
    }
    if (_requiresReceipt &&
        (_paymentReceiptUrl == null || _paymentReceiptUrl!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'أرفق صورة إيصال الدفع لطريقة الدفع المختارة.'
                : 'Upload the payment receipt image for the selected payment method.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _clearCartItems() async {
    for (final item in widget.cartItems) {
      final cartItemId = (item['cartItemId'] ?? '').toString();
      if (cartItemId.isEmpty) continue;
      try {
        await _paymentService.clearCartItem(
          customerId: widget.customerId,
          cartItemId: cartItemId,
        );
      } catch (_) {
        // Keep order success flow even if a stale cart item delete fails.
      }
    }
  }

  Future<void> _pickPaymentReceipt() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.first.bytes == null) {
      return;
    }

    setState(() => _uploadingReceipt = true);
    try {
      final file = picked.files.first;
      final url = await _mediaUploadService.uploadPaymentReceipt(
        ownerId: widget.customerId,
        fileName: file.name,
        bytes: file.bytes!,
      );
      if (!mounted) return;
      setState(() => _paymentReceiptUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.locale.languageCode == 'ar'
                ? 'تعذر رفع إيصال الدفع: $e'
                : 'Failed to upload payment receipt: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingReceipt = false);
      }
    }
  }

  void _resetDiscountVerification() {
    setState(() {
      _discountVerified = false;
      _verifiedDiscountCode = null;
    });
  }

  Future<void> _placeOrder() async {
    if (!_validateCheckoutForm()) return;

    setState(() => _placingOrder = true);
    try {
      final orderResult = await _paymentService.placeMarketplaceOrder(
        items: _quoteLines,
        shippingAddress: {
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'line1': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'notes': _notesController.text.trim(),
        },
        governorate: _selectedGovernorate,
        paymentMethod: _selectedMethod,
        discountCode: _discountController.text.trim().isEmpty
            ? null
            : _discountController.text.trim().toUpperCase(),
        paymentDetails: {
          'senderName': _paymentSenderController.text.trim(),
          'senderPhone': _phoneController.text.trim(),
          'receiptUrl': _paymentReceiptUrl,
          'notes': _notesController.text.trim(),
        },
      );

      final orderId = (orderResult['orderId'] ?? '').toString();
      final totalAmountValue = orderResult['totalAmount'];
      final totalAmount = totalAmountValue is num
          ? totalAmountValue.toDouble()
          : double.tryParse('$totalAmountValue') ?? 0;

      final payment = await _paymentService.processPayment(
        method: _selectedMethod,
        amount: totalAmount,
        orderId: orderId,
        customerId: widget.customerId,
      );
      final paymentTitle = (payment.metadata['title'] ?? '').toString();
      final paymentBody = (payment.metadata['body'] ?? '').toString();
      final paymentPrimary = (payment.metadata['phoneNumber'] ??
              payment.metadata['iban'] ??
              payment.metadata['serviceCode'] ??
              '')
          .toString();
      final paymentSecondary = (payment.metadata['accountName'] ??
              payment.metadata['bankName'] ??
              payment.metadata['mobileNumber'] ??
              '')
          .toString();

      await _clearCartItems();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          final isArabic = context.locale.languageCode == 'ar';
          final currency = 'common.currency_egp'.tr();
          return AlertDialog(
            title: Text('checkout.payment_confirmation_title'.tr()),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('checkout.placed_success'.tr()),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'فاتورة الطلب' : 'Order invoice',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${isArabic ? 'رقم الطلب: ' : 'Order ID: '}$orderId',
                          ),
                          Text(
                            '${isArabic ? 'رقم الدفع: ' : 'Payment ref: '}${payment.referenceId}',
                          ),
                          Text(
                            '${isArabic ? 'طريقة الدفع: ' : 'Payment method: '}${_paymentLabel(_selectedMethod, isArabic)}',
                          ),
                          Text(
                            '${isArabic ? 'الحالة: ' : 'Status: '}${payment.status}',
                          ),
                          const SizedBox(height: 12),
                          ...widget.cartItems.map((item) {
                            final qty =
                                ((item['quantity'] ?? 1) as num).toInt();
                            final priceValue =
                                (item['sellingPrice'] ?? item['price'] ?? 0);
                            final unitPrice = priceValue is num
                                ? priceValue.toDouble()
                                : double.tryParse('$priceValue') ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(_titleFor(item, isArabic)),
                                  ),
                                  Text('x$qty'),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${(unitPrice * qty).toStringAsFixed(2)} $currency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 20),
                          Text(
                            '${isArabic ? 'الإجمالي الفرعي: ' : 'Subtotal: '}${((orderResult['subtotalAmount'] ?? 0) as num).toDouble().toStringAsFixed(2)} $currency',
                          ),
                          Text(
                            '${isArabic ? 'الخصم: ' : 'Discount: '}${((orderResult['discountAmount'] ?? 0) as num).toDouble().toStringAsFixed(2)} $currency',
                          ),
                          Text(
                            '${isArabic ? 'الشحن: ' : 'Shipping: '}${((orderResult['shippingAmount'] ?? 0) as num).toDouble().toStringAsFixed(2)} $currency',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${isArabic ? 'الإجمالي النهائي: ' : 'Grand total: '}${totalAmount.toStringAsFixed(2)} $currency',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isArabic ? 'بيانات الاستلام' : 'Shipping details',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(_fullNameController.text.trim()),
                          Text(_phoneController.text.trim()),
                          Text(_addressController.text.trim()),
                          Text(_cityController.text.trim()),
                        ],
                      ),
                    ),
                    if (paymentTitle.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        paymentTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (paymentBody.isNotEmpty) Text(paymentBody),
                    if (paymentPrimary.isNotEmpty) Text(paymentPrimary),
                    if (paymentSecondary.isNotEmpty) Text(paymentSecondary),
                  ],
                ),
              ),
            ),
            actions: [
              if ((payment.metadata['checkoutUrl'] ?? '').toString().isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final uri = Uri.tryParse(
                      (payment.metadata['checkoutUrl'] ?? '').toString(),
                    );
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text('checkout.open_payment_page'.tr()),
                ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('common.ok'.tr()),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/customer/orders');
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
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: AppTheme.shadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required String value,
    bool strong = false,
  }) {
    final style = strong
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context, bool isArabic) {
    final steps = [
      isArabic ? 'المراجعة' : 'Review',
      isArabic ? 'العنوان' : 'Address',
      isArabic ? 'الدفع' : 'Payment',
    ];
    return Row(
      children: List.generate(steps.length, (index) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index == steps.length - 1 ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    steps[index],
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDiscountVerifier(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _discountController,
          decoration: InputDecoration(
            labelText: 'checkout.discount_code'.tr(),
            filled: _discountVerified,
            fillColor: _discountVerified
                ? Colors.green.withValues(alpha: 0.08)
                : null,
            enabledBorder: _discountVerified
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.green),
                  )
                : null,
            focusedBorder: _discountVerified
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Colors.green, width: 1.4),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _loadingTotals
                  ? null
                  : () => _loadTotals(verifyDiscount: true),
              child: Text(isArabic ? 'تحقق من الكود' : 'Verify code'),
            ),
            if (_discountVerified)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isArabic ? 'تم التحقق' : 'Verified',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (_discountVerified)
              TextButton(
                onPressed: _resetDiscountVerification,
                child: Text(isArabic ? 'إلغاء التحقق' : 'Cancel verification'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptUploader(bool isArabic) {
    if (!_requiresReceipt) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          isArabic ? 'إيصال الدفع' : 'Payment receipt',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (_paymentReceiptUrl != null && _paymentReceiptUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: RemoteImage(
              imageUrl: _paymentReceiptUrl!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorWidget: Container(
                height: 180,
                color: AppTheme.panelSoft(context),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.panelSoft(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 28),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'أرفق صورة الإيصال بعد تحويل المبلغ'
                      : 'Upload the payment receipt after completing the transfer',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _uploadingReceipt ? null : _pickPaymentReceipt,
              icon: _uploadingReceipt
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(
                isArabic ? 'إرفاق صورة الإيصال' : 'Upload receipt image',
              ),
            ),
            if (_paymentReceiptUrl != null && _paymentReceiptUrl!.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _paymentReceiptUrl = null),
                child: Text(isArabic ? 'حذف الإيصال' : 'Remove receipt'),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final totalAmountValue = _totals?['totalAmount'];
    final totalAmount = totalAmountValue is num
        ? totalAmountValue.toDouble()
        : double.tryParse('$totalAmountValue') ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(),
        title: Text('checkout.title'.tr()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          children: [
            _buildStepHeader(context, isAr),
            const SizedBox(height: 12),
            if (_hasMultipleVendors)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEAEA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8BBBB)),
                ),
                child: Text(
                  isAr
                      ? 'السلة تحتوي على أكثر من بائع. أكمل كل طلب بشكل منفصل قبل الدفع.'
                      : 'This cart contains multiple vendors. Complete each vendor order separately before payment.',
                  style: const TextStyle(color: Color(0xFF8A1C1C)),
                ),
              ),
            _buildSection(
              context: context,
              title: isAr ? 'مراجعة المنتجات' : 'Review items',
              child: Column(
                children: widget.cartItems.map((item) {
                  final quantityValue = item['quantity'];
                  final quantity = quantityValue is num
                      ? quantityValue.toInt()
                      : int.tryParse('$quantityValue') ?? 1;
                  final imageUrl = (item['imageUrl'] ?? '').toString();
                  final unitPriceValue =
                      item['unitPrice'] ?? item['price'] ?? 0;
                  final unitPrice = unitPriceValue is num
                      ? unitPriceValue.toDouble()
                      : double.tryParse('$unitPriceValue') ?? 0;
                  final title = _titleFor(item, isAr);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.panelSoft(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: AppTheme.scaffold(context),
                            child: imageUrl.isEmpty
                                ? const Icon(Icons.image_outlined)
                                : RemoteImage(
                                    imageUrl: imageUrl,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$quantity x ${unitPrice.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              title: isAr ? 'بيانات الشحن' : 'Shipping details',
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: isAr ? 'الاسم الكامل' : 'Full name',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: isAr ? 'رقم الهاتف' : 'Phone number',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'checkout.delivery_address'.tr(),
                    ),
                    minLines: 2,
                    maxLines: 3,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: isAr ? 'المدينة' : 'City',
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: isAr ? 'ملاحظات التوصيل' : 'Delivery notes',
                    ),
                    minLines: 1,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              title: isAr ? 'طريقة الشحن والدفع' : 'Shipping and payment',
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
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedGovernorate = value);
                      _loadTotals();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildDiscountVerifier(isAr),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'checkout.select_payment_method'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: PaymentMethodType.values.map((method) {
                      final selected = method == _selectedMethod;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _selectedMethod = method),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 156,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : AppTheme.panelSoft(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.border(context),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _paymentIcon(method),
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.secondaryText(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _paymentLabel(method, isAr),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final instructions = _paymentInstructions(isAr);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.panelSoft(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              instructions['title'] ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(instructions['body'] ?? ''),
                            if ((instructions['primary'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SelectableText(
                                instructions['primary']!,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                            if ((instructions['secondary'] ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  instructions['secondary']!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.secondaryText(context),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _paymentSenderController,
                    decoration: InputDecoration(
                      labelText: isAr
                          ? 'اسم المحول أو اسم صاحب البطاقة'
                          : 'Sender / cardholder name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildReceiptUploader(isAr),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              context: context,
              title: isAr ? 'ملخص الدفع' : 'Payment summary',
              child: _loadingTotals
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryRow(
                          context,
                          label: 'checkout.subtotal'.tr(),
                          value:
                              '${((_totals?['subtotal'] ?? 0) as num).toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        ),
                        _buildSummaryRow(
                          context,
                          label: 'checkout.discount'.tr(),
                          value:
                              '${((_totals?['discountAmount'] ?? 0) as num).toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        ),
                        _buildSummaryRow(
                          context,
                          label: 'checkout.tax'.tr(),
                          value:
                              '${((_totals?['taxAmount'] ?? 0) as num).toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        ),
                        _buildSummaryRow(
                          context,
                          label: 'checkout.shipping'.tr(),
                          value:
                              '${((_totals?['shippingAmount'] ?? 0) as num).toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                        ),
                        const Divider(height: 18),
                        _buildSummaryRow(
                          context,
                          label: 'checkout.total'.tr(),
                          value:
                              '${totalAmount.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                          strong: true,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed:
                  (_placingOrder || _loadingTotals || _hasMultipleVendors)
                      ? null
                      : _placeOrder,
              icon: _placingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(
                _placingOrder
                    ? 'checkout.placing_order'.tr()
                    : 'checkout.confirm_order'.tr(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
