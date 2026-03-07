import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/order_workflow.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/media_upload_service.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';
import '../../widgets/remote_image.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final Set<String> _submittingReturnForOrder = <String>{};
  final MediaUploadService _mediaUploadService = MediaUploadService();

  Color _statusColor(String status, BuildContext context) {
    switch (normalizeOrderStatus(status)) {
      case 'pending':
        return Colors.orange;
      case 'processing':
      case 'awaiting_shipment':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'out_for_delivery':
        return Colors.teal;
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
    bool uploadingEvidence = false;
    String? evidenceImageUrl;

    try {
      final proceed = await showDialog<bool>(
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
                          if (evidenceImageUrl != null &&
                              evidenceImageUrl!.trim().isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: RemoteImage(
                                imageUrl: evidenceImageUrl!,
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  height: 150,
                                  color: AppTheme.panelSoft(context),
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: uploadingEvidence
                                  ? null
                                  : () async {
                                      final picked =
                                          await FilePicker.platform.pickFiles(
                                        type: FileType.image,
                                        withData: true,
                                      );
                                      if (picked == null ||
                                          picked.files.isEmpty ||
                                          picked.files.first.bytes == null) {
                                        return;
                                      }
                                      setDialogState(
                                        () => uploadingEvidence = true,
                                      );
                                      try {
                                        final file = picked.files.first;
                                        final uploadedUrl =
                                            await _mediaUploadService
                                                .uploadReturnEvidence(
                                          ownerId: customerId,
                                          fileName: file.name,
                                          bytes: file.bytes!,
                                        );
                                        setDialogState(
                                          () => evidenceImageUrl = uploadedUrl,
                                        );
                                      } finally {
                                        if (context.mounted) {
                                          setDialogState(
                                            () => uploadingEvidence = false,
                                          );
                                        }
                                      }
                                    },
                              icon: uploadingEvidence
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.photo_camera_back_outlined),
                              label: Text(
                                context.locale.languageCode == 'ar'
                                    ? 'إرفاق صورة المنتج المرتجع'
                                    : 'Attach return product image',
                              ),
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
                        onPressed: confirm &&
                                evidenceImageUrl != null &&
                                evidenceImageUrl!.trim().isNotEmpty
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
        return status != 'seller_rejected';
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
        'imageUrl': evidenceImageUrl,
        'images': evidenceImageUrl == null ? <String>[] : <String>[evidenceImageUrl!],
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
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('nav.orders'.tr()),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${'errors.network'.tr()}: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
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
              final status = normalizeOrderStatus(
                (data['status'] ?? 'pending').toString(),
              );
              final total = ((data['totalAmount'] ?? 0) as num).toDouble();
              final tracking = (data['trackingNumber'] ?? '').toString();
              final returnStatus =
                  (data['returnRequestStatus'] ?? '').toString();
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
                    color: AppTheme.panel(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border(context)),
                    boxShadow: AppTheme.shadowSmall,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${'orders.label'.tr()}${doc.id.substring(0, 8)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
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
                              orderStatusLabel(
                                status,
                                isArabic: context.locale.languageCode == 'ar',
                              ),
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
                              '${'orders.status_prefix'.tr()}${orderStatusLabel(status, isArabic: context.locale.languageCode == 'ar')}',
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppTheme.primary,
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
