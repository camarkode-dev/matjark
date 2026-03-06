import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/marketplace_drawer.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  int _statusStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'processing':
      case 'confirmed':
      case 'sent_to_vendor':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      case 'returned':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    final statuses = [
      'orders.statuses.pending'.tr(),
      'orders.statuses.processing'.tr(),
      'orders.statuses.shipped'.tr(),
      'orders.statuses.delivered'.tr(),
      'orders.statuses.returned'.tr(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('order_tracking.title'.tr())),
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
              final status = (order['status'] ?? 'pending').toString();
              final tracking = (order['trackingNumber'] ?? '').toString();
              final step = _statusStep(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2D3B5C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'orders.label'.tr()}${docs[index].id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (tracking.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${'orders.tracking_prefix'.tr()}$tracking'),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(statuses.length, (i) {
                        final reached = i <= step;
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: i == statuses.length - 1 ? 0 : 4,
                            ),
                            height: 6,
                            decoration: BoxDecoration(
                              color: reached
                                  ? const Color(0xFF6C98FF)
                                  : const Color(0xFF2D3B5C),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(statuses.length, (i) {
                        final reached = i <= step;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: reached
                                ? const Color(
                                    0xFF6C98FF,
                                  ).withValues(alpha: 0.18)
                                : const Color(0xFF18233D),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: reached
                                  ? const Color(0xFF6C98FF)
                                  : const Color(0xFF2D3B5C),
                            ),
                          ),
                          child: Text(
                            statuses[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: reached
                                  ? const Color(0xFF89AEFF)
                                  : const Color(0xFFA6B4D3),
                            ),
                          ),
                        );
                      }),
                    ),
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
