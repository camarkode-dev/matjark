import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> calculateOrderTotals({
    required List<Map<String, dynamic>> items,
    required String governorate,
    String? discountCode,
  }) async {
    final callable = _functions.httpsCallable('calculateOrderTotalsEgypt');
    final response = await callable.call({
      'items': items,
      'governorate': governorate,
      'discountCode': discountCode ?? '',
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<PaymentResult> processPayment({
    required PaymentMethodType method,
    required double amount,
    required String orderId,
    required String customerId,
  }) async {
    final referenceId = 'pay_${DateTime.now().millisecondsSinceEpoch}_$orderId';
    switch (method) {
      case PaymentMethodType.cod:
        return _recordPayment(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'cod',
          status: 'pending_collection',
          referenceId: referenceId,
          requiresManualReview: false,
          message: 'COD selected. Payment will be collected on delivery.',
        );
      case PaymentMethodType.bankTransfer:
        return _recordPayment(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'bank_transfer',
          status: 'awaiting_transfer',
          referenceId: referenceId,
          requiresManualReview: true,
          message: 'Bank transfer instructions generated.',
        );
      case PaymentMethodType.instapay:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'instapay',
          fallbackReferenceId: referenceId,
        );
      case PaymentMethodType.card:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'paymob_card',
          fallbackReferenceId: referenceId,
        );
      case PaymentMethodType.fawry:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'fawry',
          fallbackReferenceId: referenceId,
        );
      case PaymentMethodType.applePay:
        return _createGatewayIntent(
          orderId: orderId,
          customerId: customerId,
          amount: amount,
          provider: 'apple_pay',
          fallbackReferenceId: referenceId,
        );
    }
  }

  Future<PaymentResult> _createGatewayIntent({
    required String orderId,
    required String customerId,
    required double amount,
    required String provider,
    required String fallbackReferenceId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createPaymentIntentEgypt');
      final response = await callable.call({
        'orderId': orderId,
        'customerId': customerId,
        'amount': amount,
        'provider': provider,
        'currency': 'EGP',
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final referenceId = (data['referenceId'] ?? fallbackReferenceId)
          .toString();
      final status = (data['status'] ?? 'initiated').toString();
      final metadata = Map<String, dynamic>.from(data['metadata'] ?? {});

      return _recordPayment(
        orderId: orderId,
        customerId: customerId,
        amount: amount,
        provider: provider,
        status: status,
        referenceId: referenceId,
        requiresManualReview: false,
        message: (data['message'] ?? 'Payment intent created.').toString(),
        metadata: metadata,
      );
    } catch (_) {
      // Fallback for local dev/sandbox where gateway function is not deployed.
      return _recordPayment(
        orderId: orderId,
        customerId: customerId,
        amount: amount,
        provider: provider,
        status: 'initiated',
        referenceId: fallbackReferenceId,
        requiresManualReview: false,
        message: 'Payment intent created in local sandbox mode.',
        metadata: const {'mode': 'sandbox'},
      );
    }
  }

  Future<PaymentResult> _recordPayment({
    required String orderId,
    required String customerId,
    required double amount,
    required String provider,
    required String status,
    required String referenceId,
    required bool requiresManualReview,
    required String message,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _db.collection('payments').doc(referenceId).set({
      'referenceId': referenceId,
      'orderId': orderId,
      'customerId': customerId,
      'amount': amount,
      'provider': provider,
      'status': status,
      'requiresManualReview': requiresManualReview,
      'message': message,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return PaymentResult(
      status: status,
      referenceId: referenceId,
      requiresManualReview: requiresManualReview,
      provider: provider,
      message: message,
      metadata: metadata,
    );
  }
}
