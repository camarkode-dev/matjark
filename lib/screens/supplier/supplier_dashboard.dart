import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class SupplierDashboard extends StatelessWidget {
  const SupplierDashboard({super.key});

  Stream<int> _count(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) => snap.size);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final db = FirebaseFirestore.instance;
    final productCount = _count(
      db.collection('products').where('supplierId', isEqualTo: user.uid),
    );
    final activeOrders = _count(
      db
          .collection('orders')
          .where('supplierId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'sent_to_vendor'),
    );
    final syncJobs = _count(
      db
          .collection('supplier_sync_jobs')
          .where('supplierId', isEqualTo: user.uid),
    );
    final isAr = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('supplier.dashboard'.tr()),
        actions: [
          IconButton(
            tooltip: 'nav.logout'.tr(),
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.surfaceSoft,
                  child: Icon(
                    Icons.warehouse_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'supplier.operations'.tr(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        isAr
                            ? 'إدارة المخزون ومزامنة الطلبات'
                            : 'Inventory and sync operations',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'supplier.metrics.dropshipping_products'.tr(),
            stream: productCount,
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'supplier.metrics.orders_awaiting_shipment'.tr(),
            stream: activeOrders,
            icon: Icons.local_shipping_outlined,
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'supplier.metrics.sync_jobs'.tr(),
            stream: syncJobs,
            icon: Icons.sync_alt_outlined,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('supplier.sync.channels'.tr()),
                const SizedBox(height: 10),
                _OperationRow(
                  icon: Icons.api_outlined,
                  label: 'supplier.sync.api_feed'.tr(),
                ),
                _OperationRow(
                  icon: Icons.upload_file_outlined,
                  label: 'supplier.sync.csv_queue'.tr(),
                ),
                _OperationRow(
                  icon: Icons.track_changes_outlined,
                  label: 'supplier.sync.stock_updates'.tr(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final Stream<int> stream;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.stream,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        title: Text(title),
        trailing: StreamBuilder<int>(
          stream: stream,
          builder: (context, snapshot) {
            final value = snapshot.data ?? 0;
            return Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge,
            );
          },
        ),
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OperationRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
