import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/order_workflow.dart';
import '../../providers/auth_provider.dart';
import '../../services/media_upload_service.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _tab = 0;
  final MediaUploadService _mediaUploadService = MediaUploadService();

  Stream<int> _count(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) => snap.size);
  }

  String _localizedText(BuildContext context, String ar, String en) {
    return context.locale.languageCode == 'ar' ? ar : en;
  }

  Future<void> _openProductForm(
    String sellerId, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    final titleAr = TextEditingController(
      text: (data['titleAr'] ?? '').toString(),
    );
    final titleEn = TextEditingController(
      text: (data['titleEn'] ?? '').toString(),
    );
    final descriptionAr = TextEditingController(
      text: (data['descriptionAr'] ?? '').toString(),
    );
    final descriptionEn = TextEditingController(
      text: (data['descriptionEn'] ?? '').toString(),
    );
    final price = TextEditingController(
      text: ((data['sellingPrice'] ?? 0) as num).toString(),
    );
    final stock = TextEditingController(
      text: ((data['stock'] ?? 0) as num).toInt().toString(),
    );
    final image = TextEditingController(
      text: ((data['images'] as List?)?.isNotEmpty ?? false)
          ? (data['images'] as List).first.toString()
          : '',
    );
    String? uploadedImageUrl =
        image.text.trim().isEmpty ? null : image.text.trim();
    bool uploadingImage = false;
    String? selectedCategoryId = (data['categoryId'] ?? '').toString();
    if (selectedCategoryId.isEmpty) {
      selectedCategoryId = null;
    }
    if (!mounted) return;

    final save =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                (doc == null ? 'seller.products.add' : 'seller.products.edit')
                    .tr(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleAr,
                      decoration: InputDecoration(
                        labelText: 'seller.products.title_ar'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleEn,
                      decoration: InputDecoration(
                        labelText: 'seller.products.title_en'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionAr,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _localizedText(
                          context,
                          'الوصف بالعربية',
                          'Arabic description',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionEn,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _localizedText(
                          context,
                          'الوصف بالإنجليزية',
                          'English description',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: _localizedText(
                          context,
                          'القسم',
                          'Category',
                        ),
                      ),
                      items: categoriesSnapshot.docs
                          .map(
                            (categoryDoc) => DropdownMenuItem<String>(
                              value: categoryDoc.id,
                              child: Text(
                                ((context.locale.languageCode == 'ar'
                                                ? categoryDoc.data()['nameAr']
                                                : categoryDoc.data()['nameEn']) ??
                                            categoryDoc.data()['nameAr'] ??
                                            categoryDoc.data()['nameEn'] ??
                                            categoryDoc.id)
                                        .toString(),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategoryId = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'seller.products.selling_price'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'seller.products.stock'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.locale.languageCode == 'ar'
                            ? 'صورة المنتج'
                            : 'Product image',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          uploadedImageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: AppTheme.panelSoft(context),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.panelSoft(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: uploadingImage
                          ? null
                          : () async {
                              final picked = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              if (picked == null ||
                                  picked.files.isEmpty ||
                                  picked.files.first.bytes == null) {
                                return;
                              }
                              setDialogState(() => uploadingImage = true);
                              try {
                                final file = picked.files.first;
                                final url =
                                    await _mediaUploadService.uploadProductImage(
                                  ownerId: sellerId,
                                  fileName: file.name,
                                  bytes: file.bytes!,
                                );
                                uploadedImageUrl = url;
                                image.text = url;
                              } finally {
                                if (context.mounted) {
                                  setDialogState(() => uploadingImage = false);
                                }
                              }
                            },
                      icon: uploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_outlined),
                      label: Text(
                        context.locale.languageCode == 'ar'
                            ? 'رفع صورة'
                            : 'Upload image',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: uploadingImage
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: Text('common.submit'.tr()),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!save) return;
    final parsedPrice = double.tryParse(price.text.trim()) ?? 0;
    final parsedStock = int.tryParse(stock.text.trim()) ?? -1;
    if (titleAr.text.trim().isEmpty ||
        titleEn.text.trim().isEmpty ||
        descriptionAr.text.trim().isEmpty ||
        descriptionEn.text.trim().isEmpty ||
        (selectedCategoryId ?? '').isEmpty ||
        parsedPrice <= 0 ||
        parsedStock < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('seller.products.validation_failed'.tr())),
      );
      return;
    }

    final payload = {
      'titleAr': titleAr.text.trim(),
      'titleEn': titleEn.text.trim(),
      'descriptionAr': descriptionAr.text.trim(),
      'descriptionEn': descriptionEn.text.trim(),
      'sellingPrice': parsedPrice,
      'costPrice': parsedPrice,
      'commissionAmount': double.parse((parsedPrice * 0.02).toStringAsFixed(2)),
      'stock': parsedStock,
      'images': image.text.trim().isEmpty
          ? <String>[]
          : <String>[image.text.trim()],
      'sellerId': sellerId,
      'supplierId': null,
      'categoryId': selectedCategoryId,
      'isApproved': doc == null ? false : (data['isApproved'] == true),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (doc == null) {
      await FirebaseFirestore.instance.collection('products').add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 0,
        'salesCount': 0,
      });
    } else {
      await doc.reference.set(payload, SetOptions(merge: true));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          doc == null
              ? 'seller.products.created_pending_review'.tr()
              : 'seller.products.updated_success'.tr(),
        ),
      ),
    );
  }

  Future<void> _reviewReturn({
    required QueryDocumentSnapshot<Map<String, dynamic>> returnDoc,
    required bool approve,
  }) async {
    final newStatus = approve ? 'seller_approved' : 'seller_rejected';
    final data = returnDoc.data();
    final orderId = (data['orderId'] ?? '').toString();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(returnDoc.reference, {
      'status': newStatus,
      'sellerDecision': approve ? 'approved' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (orderId.isNotEmpty) {
      final orderUpdate = <String, dynamic>{
        'returnRequestStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (approve) {
        orderUpdate['status'] = 'returned';
        orderUpdate['returnedAt'] = FieldValue.serverTimestamp();
      }
      batch.set(
        FirebaseFirestore.instance.collection('orders').doc(orderId),
        orderUpdate,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approve
              ? 'seller.dashboard_labels.return_approved'.tr()
              : 'seller.dashboard_labels.return_rejected'.tr(),
        ),
      ),
    );
  }

  Widget _buildProducts(String sellerId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        final ar = context.locale.languageCode == 'ar';
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'seller.dashboard_labels.products_management'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openProductForm(sellerId),
                    icon: const Icon(Icons.add),
                    label: Text('seller.products.add'.tr()),
                  ),
                ],
              ),
            ),
            if (docs.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.panelSoft(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: AppTheme.secondaryText(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'seller.products.no_products'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _localizedText(
                        context,
                        'يمكنك إضافة أول منتج من هنا وسيظهر بعد المراجعة.',
                        'Add your first product here. It will appear after review.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.secondaryText(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _openProductForm(sellerId),
                      icon: const Icon(Icons.add),
                      label: Text('seller.products.add'.tr()),
                    ),
                  ],
                ),
              ),
            ...docs.map((doc) {
              final d = doc.data();
              final title =
                  (ar ? d['titleAr'] : d['titleEn']) ??
                  d['titleEn'] ??
                  d['titleAr'] ??
                  doc.id;
              final approved = d['isApproved'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.panel(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: ListTile(
                  title: Text(title.toString()),
                  subtitle: Text(
                    '${(d['sellingPrice'] ?? 0)} ${'common.currency_egp'.tr()} - ${'seller.products.stock'.tr()}: ${(d['stock'] ?? 0)} - ${approved ? 'seller.products.approved'.tr() : 'seller.products.approval_pending'.tr()}',
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openProductForm(sellerId, doc: doc),
                        tooltip: 'seller.products.edit'.tr(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await doc.reference.delete();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'seller.products.deleted_success'.tr(),
                              ),
                            ),
                          );
                        },
                        tooltip: 'seller.products.delete'.tr(),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildOrders(String sellerId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text('seller.dashboard_labels.no_orders'.tr()));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          children: docs.map((doc) {
            final d = doc.data();
            final status = (d['status'] ?? 'pending').toString();
            final allowed = sellerEditableStatuses(status);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: ListTile(
                title: Text(
                  '${'seller.dashboard_labels.order_prefix'.tr()}${doc.id.substring(0, 8)}',
                ),
                subtitle: Text(
                  '${'seller.dashboard_labels.customer_prefix'.tr()}${d['customerId'] ?? '-'}',
                ),
                trailing: DropdownButton<String>(
                  value: allowed.contains(status) ? status : allowed.first,
                  items: allowed
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('orders.statuses.$s'.tr()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null || v == status) return;
                    await doc.reference.set({
                      'status': v,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildReturns(String sellerId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('returns')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text('seller.dashboard_labels.no_returns'.tr()));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          children: docs.map((doc) {
            final d = doc.data();
            final status = (d['status'] ?? 'pending_seller_review').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'seller.dashboard_labels.return_prefix'.tr()}${doc.id.substring(0, 8)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${'orders.status_prefix'.tr()}${'admin.returns.statuses.$status'.tr()}',
                  ),
                  const SizedBox(height: 8),
                  if (status == 'pending_seller_review')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _reviewReturn(returnDoc: doc, approve: false),
                            child: Text('common.cancel'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _reviewReturn(returnDoc: doc, approve: true),
                            child: Text('common.submit'.tr()),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOverview(String sellerId) {
    final productCount = _count(
      FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: sellerId),
    );
    final orderCount = _count(
      FirebaseFirestore.instance
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId),
    );
    final returnCount = _count(
      FirebaseFirestore.instance
          .collection('returns')
          .where('sellerId', isEqualTo: sellerId),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  title: 'seller.dashboard_labels.products_management'.tr(),
                  stream: productCount,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  title: 'seller.dashboard_labels.orders_management'.tr(),
                  stream: orderCount,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  title: 'seller.dashboard_labels.returns_management'.tr(),
                  stream: returnCount,
                  icon: Icons.assignment_return_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSalesAnalytics(sellerId),
        ],
      ),
    );
  }

  Widget _buildSalesAnalytics(String sellerId) {
    final stream = FirebaseFirestore.instance
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .where('status', isEqualTo: 'delivered')
        .snapshots();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          var revenue = 0.0;
          for (final doc in docs) {
            revenue += ((doc.data()['totalAmount'] ?? 0) as num).toDouble();
          }
          return Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('seller.dashboard_labels.earnings_sales'.tr()),
              ),
              Text(
                '${revenue.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    if (!user.isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/seller/waiting', (_) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        title: Text('seller.dashboard'.tr()),
        actions: [
          IconButton(
            tooltip: 'seller.dashboard_labels.switch_to_customer_mode'.tr(),
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/customer/profile', (_) => false),
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'nav.logout'.tr(),
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOverview(user.uid),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _buildProducts(user.uid),
                _buildOrders(user.uid),
                _buildReturns(user.uid),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            label: 'seller.dashboard_labels.products_management'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            label: 'seller.dashboard_labels.orders_management'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_return_outlined),
            label: 'seller.dashboard_labels.returns_management'.tr(),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String title;
  final Stream<int> stream;
  final IconData icon;

  const _MiniMetric({
    required this.title,
    required this.stream,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(height: 6),
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snap) => Text(
              '${snap.data ?? 0}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
