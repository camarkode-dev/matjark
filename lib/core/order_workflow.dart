const Map<String, List<String>> orderWorkflowTransitions = {
  'pending': ['processing'],
  'processing': ['shipped'],
  'shipped': ['delivered'],
  'delivered': ['returned'],
  'returned': [],
};

bool isValidOrderTransition(String fromStatus, String toStatus) {
  if (fromStatus == toStatus) return true;
  final allowed = orderWorkflowTransitions[fromStatus] ?? const <String>[];
  return allowed.contains(toStatus);
}

List<String> sellerEditableStatuses(String currentStatus) {
  switch (currentStatus) {
    case 'pending':
      return const ['pending', 'processing'];
    case 'processing':
      return const ['processing', 'shipped'];
    case 'shipped':
      return const ['shipped'];
    case 'delivered':
      return const ['delivered'];
    case 'returned':
      return const ['returned'];
    default:
      return <String>[currentStatus];
  }
}

bool canCustomerRequestReturn({
  required String orderStatus,
  required String returnRequestStatus,
}) {
  return orderStatus == 'delivered' && returnRequestStatus.trim().isEmpty;
}
