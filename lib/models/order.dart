import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  processing,
  awaitingShipment,
  shipped,
  outForDelivery,
  delivered,
  returned,
}

OrderStatus orderStatusFromFirestore(String? value) {
  switch (value) {
    case 'processing':
    case 'confirmed':
    case 'sent_to_vendor':
    case 'sentToSeller':
      return OrderStatus.processing;
    case 'awaiting_shipment':
      return OrderStatus.awaitingShipment;
    case 'shipped':
      return OrderStatus.shipped;
    case 'out_for_delivery':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    case 'returned':
      return OrderStatus.returned;
    case 'pending':
    default:
      return OrderStatus.pending;
  }
}

String orderStatusToFirestore(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'pending';
    case OrderStatus.processing:
      return 'processing';
    case OrderStatus.awaitingShipment:
      return 'awaiting_shipment';
    case OrderStatus.shipped:
      return 'shipped';
    case OrderStatus.outForDelivery:
      return 'out_for_delivery';
    case OrderStatus.delivered:
      return 'delivered';
    case OrderStatus.returned:
      return 'returned';
  }
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
  final String paymentStatus;
  final OrderStatus status;
  final double totalAmount;
  final double platformFee;
  final double sellerRevenue;
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
    this.paymentStatus = 'pending',
    required this.status,
    required this.totalAmount,
    this.platformFee = 0,
    this.sellerRevenue = 0,
    this.commissionAmount = 0,
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
      paymentStatus: (data['paymentStatus'] ?? 'pending').toString(),
      status: orderStatusFromFirestore(data['status'] as String?),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      platformFee: (data['platform_fee'] ?? data['commission'] ?? 0).toDouble(),
      sellerRevenue: (data['seller_revenue'] ?? data['sellerEarnings'] ?? 0)
          .toDouble(),
      commissionAmount: (data['commissionAmount'] ??
              data['commission'] ??
              data['platform_fee'] ??
              0)
          .toDouble(),
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
        'paymentStatus': paymentStatus,
        'status': orderStatusToFirestore(status),
        'totalAmount': totalAmount,
        'platform_fee': platformFee,
        'seller_revenue': sellerRevenue,
        'commissionAmount': commissionAmount,
        'trackingNumber': trackingNumber,
        'createdAt': createdAt,
      };
}
