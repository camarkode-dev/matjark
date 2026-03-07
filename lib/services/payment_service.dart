import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethodType { card, applePay, instapay, bankTransfer, cod, fawry }

extension PaymentMethodTypeX on PaymentMethodType {
  String get translationKey {
    switch (this) {
      case PaymentMethodType.card:
        return 'payment.method.card';
      case PaymentMethodType.applePay:
        return 'payment.method.applePay';
      case PaymentMethodType.instapay:
        return 'payment.method.instapay';
      case PaymentMethodType.bankTransfer:
        return 'payment.method.bankTransfer';
      case PaymentMethodType.cod:
        return 'payment.method.cod';
      case PaymentMethodType.fawry:
        return 'payment.method.fawry';
    }
  }
}

class PaymentResult {
  final String status;
  final String referenceId;
  final bool requiresManualReview;
  final String provider;
  final String message;
  final Map<String, dynamic> metadata;

  const PaymentResult({
    required this.status,
    required this.referenceId,
    required this.requiresManualReview,
    required this.provider,
    required this.message,
    this.metadata = const {},
  });
}

class PaymentService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> calculateOrderTotals({
    required List<Map<String, dynamic>> items,
    required String governorate,
    String? discountCode,
  }) async {
    final callable = _functions.httpsCallable('calculateCheckoutQuote');
    final response = await callable.call({
      'lines': items,
      'shippingZone': governorate,
      'couponCode': discountCode ?? '',
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> placeMarketplaceOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shippingAddress,
    required String governorate,
    required PaymentMethodType paymentMethod,
    String? discountCode,
    Map<String, dynamic>? paymentDetails,
  }) async {
    final callable = _functions.httpsCallable('placeMarketplaceOrder');
    final response = await callable.call({
      'lines': items,
      'shippingAddress': shippingAddress,
      'shippingZone': governorate,
      'paymentMethod': paymentMethod.name,
      'couponCode': discountCode ?? '',
      'paymentDetails': paymentDetails ?? const <String, dynamic>{},
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<PaymentResult> processPayment({
    required PaymentMethodType method,
    required double amount,
    required String orderId,
    required String customerId,
  }) async {
    switch (method) {
      case PaymentMethodType.cod:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'cod',
        );
      case PaymentMethodType.bankTransfer:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'bank_transfer',
        );
      case PaymentMethodType.instapay:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'instapay',
        );
      case PaymentMethodType.card:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'paymob_card',
        );
      case PaymentMethodType.fawry:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'fawry',
        );
      case PaymentMethodType.applePay:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'apple_pay',
        );
    }
  }

  Future<PaymentResult> _createGatewayIntent({
    required String orderId,
    required String customerId,
    required double amount,
    required String provider,
  }) async {
    try {
      final callable = _functions.httpsCallable('createPaymentIntent');
      final response = await callable.call({
        'orderId': orderId,
        'customerId': customerId,
        'amount': amount,
        'provider': provider,
        'currency': 'EGP',
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return PaymentResult(
        status: (data['status'] ?? 'initiated').toString(),
        referenceId: (data['referenceId'] ?? '').toString(),
        requiresManualReview: (data['requiresManualReview'] ?? false) == true,
        provider: (data['provider'] ?? provider).toString(),
        message: (data['message'] ?? 'Payment intent created.').toString(),
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      );
    } on FirebaseFunctionsException {
      final legacyCallable =
          _functions.httpsCallable('createPaymentIntentEgypt');
      final response = await legacyCallable.call({
        'orderId': orderId,
        'customerId': customerId,
        'amount': amount,
        'provider': provider,
        'currency': 'EGP',
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return PaymentResult(
        status: (data['status'] ?? 'initiated').toString(),
        referenceId: (data['referenceId'] ?? '').toString(),
        requiresManualReview: (data['requiresManualReview'] ?? false) == true,
        provider: (data['provider'] ?? provider).toString(),
        message: (data['message'] ?? 'Payment intent created.').toString(),
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      );
    }
  }

  Future<void> clearCartItem({
    required String customerId,
    required String cartItemId,
  }) {
    return _db
        .collection('carts')
        .doc(customerId)
        .collection('items')
        .doc(cartItemId)
        .delete();
  }
}
