import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/order_workflow.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/marketplace_drawer.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final Set<String> _submittingReturnForOrder = <String>{};

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'sent_to_vendor':
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'returned':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  Future<void> _openReturnDialog({
    required QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
    required String customerId,
  }) async {
    if (_submittingReturnForOrder.contains(orderDoc.id)) return;

    final orderData = orderDoc.data();
    final currentStatus = (orderData['status'] ?? '').toString();
    if (currentStatus != 'delivered') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('orders.return_only_delivered'.tr())),
      );
      return;
    }

    final detailsController = TextEditingController();
    String selectedReason = 'damaged_item';
    bool confirm = false;

    try {
      final proceed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: Text('orders.request_return'.tr()),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedReason,
                            decoration: InputDecoration(
                              labelText: 'orders.reason'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'damaged_item',
                                child: Text(
                                  'orders.return_reasons.damaged_item'.tr(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'wrong_item',
                                child: Text(
                                  'orders.return_reasons.wrong_item'.tr(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'missing_parts',
                                child: Text(
                                  'orders.return_reasons.missing_parts'.tr(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'not_as_described',
                                child: Text(
                                  'orders.return_reasons.not_as_described'.tr(),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('orders.return_reasons.other'.tr()),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() => selectedReason = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: detailsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'orders.details_optional'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            value: confirm,
                            contentPadding: EdgeInsets.zero,
                            title: Text('orders.confirm_return_request'.tr()),
                            onChanged: (value) =>
                                setDialogState(() => confirm = value ?? false),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text('orders.cancel'.tr()),
                      ),
                      ElevatedButton(
                        onPressed: confirm
                            ? () => Navigator.of(dialogContext).pop(true)
                            : null,
                        child: Text('orders.submit'.tr()),
                      ),
                    ],
                  );
                },
              );
            },
          ) ??
          false;

      if (!proceed) return;

      setState(() => _submittingReturnForOrder.add(orderDoc.id));
      final db = FirebaseFirestore.instance;

      final existing = await db
          .collection('returns')
          .where('orderId', isEqualTo: orderDoc.id)
          .where('customerId', isEqualTo: customerId)
          .limit(10)
          .get();

      final hasOpenReturn = existing.docs.any((doc) {
        final status = (doc.data()['status'] ?? '').toString();
        return status != 'seller_rejected' && status != 'admin_rejected';
      });

      if (hasOpenReturn) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('orders.return_exists'.tr())));
        }
        return;
      }

      final returnRef = db.collection('returns').doc();
      await returnRef.set({
        'returnId': returnRef.id,
        'orderId': orderDoc.id,
        'customerId': customerId,
        'sellerId': orderData['sellerId'],
        'supplierId': orderData['supplierId'],
        'status': 'pending_seller_review',
        'reason': selectedReason,
        'details': detailsController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await orderDoc.reference.set({
        'returnRequestId': returnRef.id,
        'returnRequestStatus': 'pending_seller_review',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('orders.return_submitted'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'errors.network'.tr()}: $e')));
      }
    } finally {
      detailsController.dispose();
      if (mounted) {
        setState(() => _submittingReturnForOrder.remove(orderDoc.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      drawer: const MarketplaceDrawer(),
      appBar: AppBar(title: Text('nav.orders'.tr())),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'orders.none'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            itemCount: docs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final status = (data['status'] ?? 'pending').toString();
              final total = ((data['totalAmount'] ?? 0) as num).toDouble();
              final tracking = (data['trackingNumber'] ?? '').toString();
              final returnStatus = (data['returnRequestStatus'] ?? '')
                  .toString();
              final isSubmittingReturn = _submittingReturnForOrder.contains(
                doc.id,
              );

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () =>
                    Navigator.of(context).pushNamed('/customer/tracking'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111A2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2D3B5C)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${'orders.label'.tr()}${doc.id.substring(0, 8)}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(
                                status,
                                context,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'orders.statuses.$status'.tr(),
                              style: TextStyle(
                                color: _statusColor(status, context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${'orders.status_prefix'.tr()}${'orders.statuses.$status'.tr()}',
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF6C98FF),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      if (tracking.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${'orders.tracking_prefix'.tr()}$tracking',
                          ),
                        ),
                      ],
                      if (returnStatus.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${'orders.return_prefix'.tr()}${'admin.returns.statuses.$returnStatus'.tr()}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      if (canCustomerRequestReturn(
                        orderStatus: status,
                        returnRequestStatus: returnStatus,
                      ))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                            onPressed: isSubmittingReturn
                                ? null
                                : () => _openReturnDialog(
                                    orderDoc: doc,
                                    customerId: user.uid,
                                  ),
                            icon: isSubmittingReturn
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.assignment_return_outlined),
                            label: Text('orders.request_return'.tr()),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
