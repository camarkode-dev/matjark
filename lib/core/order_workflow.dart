const List<String> orderManagementStatuses = <String>[
  'pending',
  'processing',
  'awaiting_shipment',
  'shipped',
  'out_for_delivery',
  'delivered',
  'returned',
];

const List<String> orderTrackingStatuses = <String>[
  'pending',
  'processing',
  'awaiting_shipment',
  'shipped',
  'out_for_delivery',
  'delivered',
];

const List<String> returnManagementStatuses = <String>[
  'pending_seller_review',
  'seller_accepted',
  'awaiting_return_item',
  'returned_completed',
  'seller_rejected',
];

const Map<String, List<String>> orderWorkflowTransitions = {
  'pending': ['processing'],
  'processing': ['awaiting_shipment'],
  'awaiting_shipment': ['shipped'],
  'shipped': ['out_for_delivery'],
  'out_for_delivery': ['delivered'],
  'delivered': ['returned'],
  'returned': [],
};

String normalizeOrderStatus(String status) {
  switch (status) {
    case 'confirmed':
    case 'sent_to_vendor':
      return 'processing';
    default:
      return status.trim().isEmpty ? 'pending' : status.trim();
  }
}

bool isValidOrderTransition(String fromStatus, String toStatus) {
  final normalizedFrom = normalizeOrderStatus(fromStatus);
  final normalizedTo = normalizeOrderStatus(toStatus);
  if (normalizedFrom == normalizedTo) return true;
  final allowed =
      orderWorkflowTransitions[normalizedFrom] ?? const <String>[];
  return allowed.contains(normalizedTo);
}

List<String> sellerEditableStatuses(String currentStatus) {
  final normalized = normalizeOrderStatus(currentStatus);
  switch (normalized) {
    case 'pending':
      return const ['pending', 'processing'];
    case 'processing':
      return const ['processing', 'awaiting_shipment'];
    case 'awaiting_shipment':
      return const ['awaiting_shipment', 'shipped'];
    case 'shipped':
      return const ['shipped', 'out_for_delivery'];
    case 'out_for_delivery':
      return const ['out_for_delivery', 'delivered'];
    case 'delivered':
      return const ['delivered'];
    case 'returned':
      return const ['returned'];
    default:
      return <String>[normalized];
  }
}

int orderStatusStep(String status) {
  switch (normalizeOrderStatus(status)) {
    case 'pending':
      return 0;
    case 'processing':
      return 1;
    case 'awaiting_shipment':
      return 2;
    case 'shipped':
      return 3;
    case 'out_for_delivery':
      return 4;
    case 'delivered':
    case 'returned':
      return 5;
    default:
      return 0;
  }
}

bool isActiveOrderStatus(String status) {
  final normalized = normalizeOrderStatus(status);
  return normalized == 'pending' ||
      normalized == 'processing' ||
      normalized == 'awaiting_shipment' ||
      normalized == 'shipped' ||
      normalized == 'out_for_delivery';
}

String orderStatusLabel(String status, {required bool isArabic}) {
  switch (normalizeOrderStatus(status)) {
    case 'pending':
      return isArabic ? 'تم استلام الطلب' : 'Order received';
    case 'processing':
      return isArabic ? 'قيد المعالجة' : 'Processing';
    case 'awaiting_shipment':
      return isArabic ? 'قيد الانتظار' : 'Awaiting shipment';
    case 'shipped':
      return isArabic ? 'تم الشحن' : 'Shipped';
    case 'out_for_delivery':
      return isArabic ? 'في الطريق' : 'Out for delivery';
    case 'delivered':
      return isArabic ? 'تم التسليم' : 'Delivered';
    case 'returned':
      return isArabic ? 'تم الإرجاع' : 'Returned';
    default:
      return isArabic ? 'تم استلام الطلب' : 'Order received';
  }
}

bool canCustomerRequestReturn({
  required String orderStatus,
  required String returnRequestStatus,
}) {
  return normalizeOrderStatus(orderStatus) == 'delivered' &&
      returnRequestStatus.trim().isEmpty;
}

String returnStatusLabel(String status, {required bool isArabic}) {
  switch (status.trim()) {
    case 'pending_seller_review':
      return isArabic ? 'بانتظار مراجعة البائع' : 'Pending seller review';
    case 'seller_accepted':
      return isArabic ? 'تم قبول المرتجع' : 'Return accepted';
    case 'awaiting_return_item':
      return isArabic ? 'بانتظار استلام المنتج المرتجع' : 'Awaiting returned item';
    case 'returned_completed':
      return isArabic ? 'تم الاسترجاع' : 'Refund completed';
    case 'seller_rejected':
      return isArabic ? 'تم رفض المرتجع' : 'Return rejected';
    case 'admin_approved':
      return isArabic ? 'اعتماد الإدارة' : 'Admin approved';
    case 'admin_rejected':
      return isArabic ? 'رفض الإدارة' : 'Admin rejected';
    default:
      return isArabic ? 'بانتظار مراجعة البائع' : 'Pending seller review';
  }
}
