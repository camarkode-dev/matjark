import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/order_workflow.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/marketplace_drawer.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final isArabic = context.locale.languageCode == 'ar';

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(hasDrawer: true),
        title: Text('order_tracking.title'.tr()),
      ),
      drawer: const MarketplaceDrawer(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text('order_tracking.none'.tr()));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final order = docs[index].data();
              final status = normalizeOrderStatus(
                (order['status'] ?? 'pending').toString(),
              );
              final tracking = (order['trackingNumber'] ?? '').toString();
              final step = orderStatusStep(status);
              final isReturned = status == 'returned';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.panel(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border(context)),
                  boxShadow: AppTheme.shadowSmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${'orders.label'.tr()}${docs[index].id.substring(0, 8)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isReturned ? Colors.red : AppTheme.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            orderStatusLabel(status, isArabic: isArabic),
                            style: TextStyle(
                              color: isReturned ? Colors.red : AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tracking.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${'orders.tracking_prefix'.tr()}$tracking',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.secondaryText(context),
                            ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: List.generate(orderTrackingStatuses.length, (i) {
                        final reached = i <= step;
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: i == orderTrackingStatuses.length - 1
                                  ? 0
                                  : 6,
                            ),
                            height: 7,
                            decoration: BoxDecoration(
                              color: reached
                                  ? AppTheme.primary
                                  : AppTheme.border(context),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: orderTrackingStatuses.map((item) {
                        final itemStep = orderStatusStep(item);
                        final reached = itemStep <= step;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: reached
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.panelSoft(context),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: reached
                                  ? AppTheme.primary.withValues(alpha: 0.4)
                                  : AppTheme.border(context),
                            ),
                          ),
                          child: Text(
                            orderStatusLabel(item, isArabic: isArabic),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: reached
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: reached
                                  ? AppTheme.primary
                                  : AppTheme.secondaryText(context),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (isReturned) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          isArabic
                              ? 'تم تسجيل هذا الطلب كطلب مُرجع.'
                              : 'This order has been marked as returned.',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
