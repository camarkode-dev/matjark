import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  processing,
  sentToSeller,
  shipped,
  delivered,
  returned,
}

class OrderItem {
  final String productId;
  final int quantity;
  final double price;

  OrderItem({required this.productId, required this.quantity, required this.price});

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'quantity': quantity,
        'price': price,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'],
      quantity: map['quantity'],
      price: map['price'].toDouble(),
    );
  }
}

class Order {
  final String id;
  final String customerId;
  final String? sellerId;
  final String? supplierId;
  final List<OrderItem> items;
  final String paymentMethod;
  final OrderStatus status;
  final double totalAmount;
  final double commissionAmount;
  final String? trackingNumber;
  final Timestamp createdAt;

  Order({
    required this.id,
    required this.customerId,
    this.sellerId,
    this.supplierId,
    required this.items,
    required this.paymentMethod,
    required this.status,
    required this.totalAmount,
    required this.commissionAmount,
    this.trackingNumber,
    required this.createdAt,
  });

  factory Order.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      customerId: data['customerId'],
      sellerId: data['sellerId'],
      supplierId: data['supplierId'],
      items: (data['items'] as List<dynamic>)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      paymentMethod: data['paymentMethod'],
      status: OrderStatus.values.firstWhere(
          (e) => e.toString().split('.').last == data['status']),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0).toDouble(),
      trackingNumber: data['trackingNumber'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'sellerId': sellerId,
        'supplierId': supplierId,
        'items': items.map((e) => e.toMap()).toList(),
        'paymentMethod': paymentMethod,
        'status': status.toString().split('.').last,
        'totalAmount': totalAmount,
        'commissionAmount': commissionAmount,
        'trackingNumber': trackingNumber,
        'createdAt': createdAt,
      };
}
