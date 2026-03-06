import 'package:flutter_test/flutter_test.dart';

import 'package:matjark/core/order_workflow.dart';
import 'package:matjark/services/payment_service.dart';

void main() {
  group('Order workflow validation', () {
    test('allows only valid sequential transitions', () {
      expect(isValidOrderTransition('pending', 'processing'), isTrue);
      expect(isValidOrderTransition('processing', 'shipped'), isTrue);
      expect(isValidOrderTransition('shipped', 'delivered'), isTrue);
      expect(isValidOrderTransition('delivered', 'returned'), isTrue);

      expect(isValidOrderTransition('pending', 'shipped'), isFalse);
      expect(isValidOrderTransition('processing', 'returned'), isFalse);
      expect(isValidOrderTransition('returned', 'processing'), isFalse);
    });

    test(
      'seller editable statuses do not expose delivered completion from shipped',
      () {
        expect(
          sellerEditableStatuses('pending'),
          equals(<String>['pending', 'processing']),
        );
        expect(
          sellerEditableStatuses('processing'),
          equals(<String>['processing', 'shipped']),
        );
        expect(sellerEditableStatuses('shipped'), equals(<String>['shipped']));
        expect(
          sellerEditableStatuses('delivered'),
          equals(<String>['delivered']),
        );
      },
    );

    test(
      'customer return request allowed only for delivered orders without prior request',
      () {
        expect(
          canCustomerRequestReturn(
            orderStatus: 'delivered',
            returnRequestStatus: '',
          ),
          isTrue,
        );
        expect(
          canCustomerRequestReturn(
            orderStatus: 'processing',
            returnRequestStatus: '',
          ),
          isFalse,
        );
        expect(
          canCustomerRequestReturn(
            orderStatus: 'delivered',
            returnRequestStatus: 'pending_seller_review',
          ),
          isFalse,
        );
      },
    );
  });

  group('Payment methods validation', () {
    test('all required payment methods are exposed', () {
      final keys = PaymentMethodType.values
          .map((m) => m.translationKey)
          .toList();
      expect(keys, contains('payment.method.card'));
      expect(keys, contains('payment.method.applePay'));
      expect(keys, contains('payment.method.instapay'));
      expect(keys, contains('payment.method.bankTransfer'));
      expect(keys, contains('payment.method.cod'));
      expect(keys, contains('payment.method.fawry'));
    });
  });
}
