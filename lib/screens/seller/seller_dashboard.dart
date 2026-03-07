import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/order_workflow.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/media_upload_service.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/remote_image.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _tab = 0;
  final MediaUploadService _mediaUploadService = MediaUploadService();

  String? _resolveOwnedSellerId(Map<String, dynamic> data) {
    final sellerId = (data['sellerId'] ?? '').toString().trim();
    if (sellerId.isNotEmpty) {
      return sellerId;
    }
    final vendorId = (data['vendorId'] ?? '').toString().trim();
    return vendorId.isEmpty ? null : vendorId;
  }

  bool _isOwnedBySeller(Map<String, dynamic> data, String sellerId) {
    return _resolveOwnedSellerId(data) == sellerId;
  }

  Future<bool> _ensureSellerOwnership({
    required Map<String, dynamic> data,
    required String sellerId,
    required String entityAr,
    required String entityEn,
  }) async {
    if (_isOwnedBySeller(data, sellerId)) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _localizedText(
            context,
            'لا يمكنك إدارة $entityAr لأنه لا يتبع حسابك.',
            'You can only manage your own $entityEn.',
          ),
        ),
      ),
    );
    return false;
  }

  Stream<int> _count(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) => snap.size);
  }

  String _localizedText(BuildContext context, String ar, String en) {
    return context.locale.languageCode == 'ar' ? ar : en;
  }

  String _formatQueryError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return context.locale.languageCode == 'ar'
            ? 'ليس لديك صلاحية للوصول إلى بيانات البائع.'
            : 'You do not have permission to access seller data.';
      }
      return error.message ?? error.code;
    }
    return error.toString();
  }

  Widget _buildQueryError(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD4D4)),
      ),
      child: Text(
        _formatQueryError(error),
        style: const TextStyle(color: Color(0xFF8A1C1C)),
      ),
    );
  }

  Future<bool> _confirmSellerAction({
    required String title,
    required String message,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                style: destructive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('common.submit'.tr()),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _updateProductAvailability(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool isActive,
    String sellerId,
  ) async {
    if (!await _ensureSellerOwnership(
      data: doc.data(),
      sellerId: sellerId,
      entityAr: 'المنتج',
      entityEn: 'product',
    )) {
      return;
    }
    await doc.reference.set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isActive
              ? _localizedText(
                  context, 'تم تفعيل المنتج.', 'Product activated.')
              : _localizedText(
                  context, 'تم إيقاف المنتج.', 'Product disabled.'),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String sellerId,
  ) async {
    if (!await _ensureSellerOwnership(
      data: doc.data(),
      sellerId: sellerId,
      entityAr: 'المنتج',
      entityEn: 'product',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    final confirmed = await _confirmSellerAction(
      title: _localizedText(context, 'حذف المنتج', 'Delete product'),
      message: _localizedText(
        context,
        'سيتم حذف المنتج نهائياً من لوحة البائع.',
        'This product will be permanently removed from the seller dashboard.',
      ),
      destructive: true,
    );
    if (!confirmed) return;
    await doc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('seller.products.deleted_success'.tr())),
    );
  }

  Future<void> _updateOrderStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String newStatus,
    String sellerId,
  ) async {
    if (!await _ensureSellerOwnership(
      data: doc.data(),
      sellerId: sellerId,
      entityAr: 'الطلب',
      entityEn: 'order',
    )) {
      return;
    }
    final status = normalizeOrderStatus(
      (doc.data()['status'] ?? 'pending').toString(),
    );
    if (newStatus == status) return;

    final payload = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == 'processing') {
      payload['processingAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'awaiting_shipment') {
      payload['awaitingShipmentAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'shipped') {
      payload['shippedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'out_for_delivery') {
      payload['outForDeliveryAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == 'delivered') {
      payload['deliveredAt'] = FieldValue.serverTimestamp();
    }

    await doc.reference.set(payload, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _localizedText(
            context,
            'تم تحديث حالة الطلب.',
            'Order status updated.',
          ),
        ),
      ),
    );
  }

  Future<void> _editTrackingNumber(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String sellerId,
  ) async {
    if (!await _ensureSellerOwnership(
      data: doc.data(),
      sellerId: sellerId,
      entityAr: 'الطلب',
      entityEn: 'order',
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    final controller = TextEditingController(
      text: (doc.data()['trackingNumber'] ?? '').toString(),
    );
    final save = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              _localizedText(context, 'رقم التتبع', 'Tracking number'),
            ),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: _localizedText(
                  context,
                  'أدخل رقم التتبع',
                  'Enter tracking number',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('common.submit'.tr()),
              ),
            ],
          ),
        ) ??
        false;
    if (!save) return;
    await doc.reference.set({
      'trackingNumber': controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _localizedText(
            context,
            'تم تحديث رقم التتبع.',
            'Tracking number updated.',
          ),
        ),
      ),
    );
  }

  String _customerName(Map<String, dynamic> data) {
    final direct = (data['customerName'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final address = data['address'];
    if (address is Map) {
      final fromAddress = (address['fullName'] ?? '').toString().trim();
      if (fromAddress.isNotEmpty) return fromAddress;
    }
    return (data['customerId'] ?? '-').toString();
  }

  Future<void> _hideOrderForSeller(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String sellerId,
  ) async {
    if (!await _ensureSellerOwnership(
      data: doc.data(),
      sellerId: sellerId,
      entityAr: 'الطلب',
      entityEn: 'order',
    )) {
      return;
    }
    await doc.reference.set({
      'hiddenForSeller': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _hideReturnForSeller(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String sellerId,
  ) async {
    if (!await _ensureSellerOwnership(
      data: doc.data(),
      sellerId: sellerId,
      entityAr: 'المرتجع',
      entityEn: 'return request',
    )) {
      return;
    }
    await doc.reference.set({
      'hiddenForSeller': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Widget _statusChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _openProductForm(
    String sellerId, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    if (doc != null && !_isOwnedBySeller(data, sellerId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localizedText(
                context,
                'لا يمكنك تعديل منتج لا يتبع حسابك.',
                'You can only edit your own product.',
              ),
            ),
          ),
        );
      }
      return;
    }
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

    final save = await showDialog<bool>(
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
                    if (uploadedImageUrl != null &&
                        uploadedImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RemoteImage(
                          imageUrl: uploadedImageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: Container(
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
                              setDialogState(() => uploadingImage = true);
                              try {
                                final file = picked.files.first;
                                final url = await _mediaUploadService
                                    .uploadProductImage(
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

    final normalizedTitleAr = titleAr.text.trim();
    final normalizedTitleEn = titleEn.text.trim();
    final normalizedDescriptionAr = descriptionAr.text.trim();
    final normalizedDescriptionEn = descriptionEn.text.trim();
    final normalizedImageUrl = image.text.trim();
    final normalizedName =
        normalizedTitleEn.isNotEmpty ? normalizedTitleEn : normalizedTitleAr;
    final normalizedSearchText =
        '$normalizedTitleAr $normalizedTitleEn'.toLowerCase().trim();

    final payload = {
      'titleAr': normalizedTitleAr,
      'titleEn': normalizedTitleEn,
      'descriptionAr': normalizedDescriptionAr,
      'descriptionEn': normalizedDescriptionEn,
      'name': normalizedName,
      'nameLower': normalizedName.toLowerCase(),
      'searchKeywords': normalizedSearchText.isEmpty
          ? <String>[]
          : normalizedSearchText
              .split(RegExp(r'\s+'))
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
      'sellingPrice': parsedPrice,
      'price': parsedPrice,
      'costPrice': parsedPrice,
      'commissionAmount': double.parse((parsedPrice * 0.02).toStringAsFixed(2)),
      'stock': parsedStock,
      'images': normalizedImageUrl.isEmpty
          ? <String>[]
          : <String>[normalizedImageUrl],
      'imageUrl': normalizedImageUrl,
      'sellerId': sellerId,
      'vendorId': sellerId,
      'supplierId': null,
      'categoryId': selectedCategoryId,
      'isActive': true,
      'isApproved': true,
      'stockStatus': parsedStock > 0 ? 'in_stock' : 'out_of_stock',
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
              ? _localizedText(
                  context,
                  'تمت إضافة المنتج بنجاح.',
                  'Product added successfully.',
                )
              : 'seller.products.updated_success'.tr(),
        ),
      ),
    );
  }

  Future<void> _reviewReturn({
    required QueryDocumentSnapshot<Map<String, dynamic>> returnDoc,
    required bool approve,
    required String sellerId,
  }) async {
    final newStatus = approve ? 'seller_accepted' : 'seller_rejected';
    final data = returnDoc.data();
    if (!await _ensureSellerOwnership(
      data: data,
      sellerId: sellerId,
      entityAr: 'المرتجع',
      entityEn: 'return request',
    )) {
      return;
    }
    final orderId = (data['orderId'] ?? '').toString();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(
        returnDoc.reference,
        {
          'status': newStatus,
          'sellerDecision': approve ? 'approved' : 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));

    if (orderId.isNotEmpty) {
      final orderUpdate = <String, dynamic>{
        'returnRequestStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
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

  Future<void> _advanceReturnStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> returnDoc,
    String nextStatus,
    String sellerId,
  ) async {
    final data = returnDoc.data();
    if (!await _ensureSellerOwnership(
      data: data,
      sellerId: sellerId,
      entityAr: 'المرتجع',
      entityEn: 'return request',
    )) {
      return;
    }
    final orderId = (data['orderId'] ?? '').toString();
    final batch = FirebaseFirestore.instance.batch();
    final payload = <String, dynamic>{
      'status': nextStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (nextStatus == 'awaiting_return_item') {
      payload['awaitingReturnItemAt'] = FieldValue.serverTimestamp();
    }
    if (nextStatus == 'returned_completed') {
      payload['completedAt'] = FieldValue.serverTimestamp();
      payload['sellerDecision'] = 'approved';
    }
    batch.set(returnDoc.reference, payload, SetOptions(merge: true));
    if (orderId.isNotEmpty) {
      final orderPayload = <String, dynamic>{
        'returnRequestStatus': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (nextStatus == 'returned_completed') {
        orderPayload['status'] = 'returned';
        orderPayload['returnedAt'] = FieldValue.serverTimestamp();
      }
      batch.set(
        FirebaseFirestore.instance.collection('orders').doc(orderId),
        orderPayload,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
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
        if (snap.hasError) {
          return Center(child: _buildQueryError(snap.error!));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? [])
            .where((doc) => _isOwnedBySeller(doc.data(), sellerId))
            .where((doc) => doc.data()['hiddenForSeller'] != true)
            .toList();
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
                        'Add your first product here. It will appear to customers right away.',
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
              final title = (ar ? d['titleAr'] : d['titleEn']) ??
                  d['titleEn'] ??
                  d['titleAr'] ??
                  doc.id;
              final approved = d['isApproved'] == true;
              final isActive = d['isActive'] != false;
              final stockValue = d['stock'];
              final stock = stockValue is num
                  ? stockValue.toInt()
                  : int.tryParse('$stockValue') ?? 0;
              final priceValue = d['sellingPrice'] ?? d['price'] ?? 0;
              final price = priceValue is num
                  ? priceValue.toDouble()
                  : double.tryParse('$priceValue') ?? 0;
              final platformFee = double.parse(
                (price * 0.02).toStringAsFixed(2),
              );
              final sellerNet = double.parse(
                (price - platformFee).toStringAsFixed(2),
              );
              final imageUrl = ((d['images'] as List?)?.isNotEmpty ?? false)
                  ? (d['images'] as List).first.toString()
                  : (d['imageUrl'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.panel(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imageUrl.trim().isEmpty
                            ? Container(
                                width: 58,
                                height: 58,
                                color: AppTheme.panelSoft(context),
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_outlined),
                              )
                            : RemoteImage(
                                imageUrl: imageUrl,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  width: 58,
                                  height: 58,
                                  color: AppTheme.panelSoft(context),
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${price.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _statusChip(
                                  context,
                                  _localizedText(
                                    context,
                                    'السعر ${price.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                    'Price ${price.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                  ),
                                  AppTheme.primary,
                                ),
                                _statusChip(
                                  context,
                                  _localizedText(
                                    context,
                                    'عمولة 2% ${platformFee.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                    '2% fee ${platformFee.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                  ),
                                  Colors.orange,
                                ),
                                _statusChip(
                                  context,
                                  _localizedText(
                                    context,
                                    'الصافي ${sellerNet.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                    'Net ${sellerNet.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                                  ),
                                  Colors.green,
                                ),
                                _statusChip(
                                  context,
                                  '${'seller.products.stock'.tr()}: $stock',
                                  stock > 0 ? Colors.green : Colors.orange,
                                ),
                                _statusChip(
                                  context,
                                  approved
                                      ? 'seller.products.approved'.tr()
                                      : _localizedText(
                                          context,
                                          'جاهز للنشر',
                                          'Ready to publish',
                                        ),
                                  approved ? Colors.green : Colors.orange,
                                ),
                                _statusChip(
                                  context,
                                  isActive
                                      ? _localizedText(
                                          context,
                                          'نشط',
                                          'Active',
                                        )
                                      : _localizedText(
                                          context,
                                          'متوقف',
                                          'Inactive',
                                        ),
                                  isActive ? Colors.blue : Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _openProductForm(sellerId, doc: doc),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text('seller.products.edit'.tr()),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _updateProductAvailability(
                                    doc,
                                    !isActive,
                                    sellerId,
                                  ),
                                  icon: Icon(
                                    isActive
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  label: Text(
                                    isActive
                                        ? _localizedText(
                                            context,
                                            'إيقاف',
                                            'Disable',
                                          )
                                        : _localizedText(
                                            context,
                                            'تفعيل',
                                            'Activate',
                                          ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _deleteProduct(doc, sellerId),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text('seller.products.delete'.tr()),
                                ),
                              ],
                            ),
                          ],
                        ),
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
        if (snap.hasError) {
          return Center(child: _buildQueryError(snap.error!));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? [])
            .where((doc) => _isOwnedBySeller(doc.data(), sellerId))
            .where((doc) => doc.data()['hiddenForSeller'] != true)
            .toList();
        if (docs.isEmpty) {
          return Center(child: Text('seller.dashboard_labels.no_orders'.tr()));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          children: docs.map((doc) {
            final d = doc.data();
            final status = normalizeOrderStatus(
              (d['status'] ?? 'pending').toString(),
            );
            final allowed = sellerEditableStatuses(status);
            final tracking = (d['trackingNumber'] ?? '').toString();
            final totalValue = d['totalAmount'] ?? 0;
            final total = totalValue is num
                ? totalValue.toDouble()
                : double.tryParse('$totalValue') ?? 0;
            final canHide = status == 'delivered' || status == 'returned';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${'seller.dashboard_labels.order_prefix'.tr()}${doc.id.substring(0, 8)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(
                        context,
                        orderStatusLabel(
                          status,
                          isArabic: context.locale.languageCode == 'ar',
                        ),
                        Colors.blue,
                      ),
                      if (canHide)
                        IconButton(
                          tooltip: _localizedText(
                            context,
                            'إخفاء الطلب',
                            'Hide order',
                          ),
                          onPressed: () => _hideOrderForSeller(doc, sellerId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'seller.dashboard_labels.customer_prefix'.tr()}${_customerName(d)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${total.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (tracking.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_localizedText(context, 'رقم التتبع: ', 'Tracking: ')}$tracking',
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              allowed.contains(status) ? status : allowed.first,
                          decoration: InputDecoration(
                            labelText: _localizedText(
                              context,
                              'حالة الطلب',
                              'Order status',
                            ),
                          ),
                          items: allowed
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    orderStatusLabel(
                                      s,
                                      isArabic:
                                          context.locale.languageCode == 'ar',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            _updateOrderStatus(doc, v, sellerId);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _editTrackingNumber(doc, sellerId),
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: Text(
                          _localizedText(context, 'التتبع', 'Tracking'),
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

  Widget _buildReturns(String sellerId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('returns')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: _buildQueryError(snap.error!));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? [])
            .where((doc) => _isOwnedBySeller(doc.data(), sellerId))
            .toList();
        if (docs.isEmpty) {
          return Center(child: Text('seller.dashboard_labels.no_returns'.tr()));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          children: docs.map((doc) {
            final d = doc.data();
            final status = (d['status'] ?? 'pending_seller_review').toString();
            final reason = (d['reason'] ?? '').toString();
            final details = (d['details'] ?? '').toString();
            final evidenceImage = ((d['images'] as List?)?.isNotEmpty ?? false)
                ? (d['images'] as List).first.toString()
                : (d['imageUrl'] ?? '').toString();
            final canHide = status == 'returned_completed' ||
                status == 'seller_rejected';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panel(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${'seller.dashboard_labels.return_prefix'.tr()}${doc.id.substring(0, 8)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _statusChip(
                        context,
                        returnStatusLabel(
                          status,
                          isArabic: context.locale.languageCode == 'ar',
                        ),
                        status == 'pending_seller_review'
                            ? Colors.orange
                            : status == 'seller_accepted' ||
                                    status == 'returned_completed'
                                ? Colors.green
                                : status == 'awaiting_return_item'
                                    ? Colors.blue
                                    : Colors.redAccent,
                      ),
                      if (canHide)
                        IconButton(
                          tooltip: _localizedText(
                            context,
                            'إخفاء المرتجع',
                            'Hide return',
                          ),
                          onPressed: () => _hideReturnForSeller(doc, sellerId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_localizedText(context, 'رقم الطلب: ', 'Order: ')}${(d['orderId'] ?? '-').toString().substring(0, ((d['orderId'] ?? '-').toString().length > 8) ? 8 : (d['orderId'] ?? '-').toString().length)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'orders.status_prefix'.tr()}${returnStatusLabel(status, isArabic: context.locale.languageCode == 'ar')}',
                  ),
                  if (evidenceImage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RemoteImage(
                        imageUrl: evidenceImage,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          height: 150,
                          color: AppTheme.panelSoft(context),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ],
                  if (reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_localizedText(context, 'السبب: ', 'Reason: ')}${'orders.return_reasons.$reason'.tr()}',
                    ),
                  ],
                  if (details.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_localizedText(context, 'التفاصيل: ', 'Details: ')}$details',
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (status == 'pending_seller_review')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _reviewReturn(
                              returnDoc: doc,
                              approve: false,
                              sellerId: sellerId,
                            ),
                            child: Text('common.cancel'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _reviewReturn(
                              returnDoc: doc,
                              approve: true,
                              sellerId: sellerId,
                            ),
                            child: Text('common.submit'.tr()),
                          ),
                        ),
                      ],
                    ),
                  if (status == 'seller_accepted') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _advanceReturnStatus(
                          doc,
                          'awaiting_return_item',
                          sellerId,
                        ),
                        icon: const Icon(Icons.move_down_outlined),
                        label: Text(
                          _localizedText(
                            context,
                            'في انتظار استلام المنتج المرتجع',
                            'Await returned item',
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (status == 'awaiting_return_item') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _advanceReturnStatus(
                          doc,
                          'returned_completed',
                          sellerId,
                        ),
                        icon: const Icon(Icons.task_alt_outlined),
                        label: Text(
                          _localizedText(
                            context,
                            'تم الاسترجاع',
                            'Refund completed',
                          ),
                        ),
                      ),
                    ),
                  ],
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
          var totalSales = 0.0;
          var soldUnits = 0;
          var sellerNet = 0.0;
          for (final doc in docs) {
            final data = doc.data();
            final items = (data['items'] as List?) ?? const [];
            var matchedOrderTotal = 0.0;
            var matchedUnits = 0;
            for (final item in items) {
              if (item is! Map) continue;
              final itemSellerId =
                  (item['sellerId'] ?? item['vendorId'] ?? '').toString();
              if (itemSellerId != sellerId) continue;
              final quantity = ((item['quantity'] ?? 0) as num).toInt();
              final unitPrice =
                  ((item['unitPrice'] ?? item['price'] ?? 0) as num)
                      .toDouble();
              matchedUnits += quantity;
              matchedOrderTotal += quantity * unitPrice;
            }
            if (matchedUnits == 0 &&
                (data['sellerId'] ?? data['vendorId'] ?? '').toString() ==
                    sellerId) {
              matchedOrderTotal =
                  ((data['totalAmount'] ?? 0) as num).toDouble();
            }
            totalSales += matchedOrderTotal;
            soldUnits += matchedUnits;
            sellerNet += ((data['seller_revenue'] ??
                        (matchedOrderTotal * 0.98)) as num)
                    .toDouble();
          }
          final isAr = context.locale.languageCode == 'ar';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('seller.dashboard_labels.earnings_sales'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SellerAmountChip(
                    title: isAr ? 'إجمالي مبيعاتي' : 'My total sales',
                    value:
                        '${totalSales.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                  ),
                  _SellerAmountChip(
                    title: isAr ? 'صافي بعد 2%' : 'Net after 2%',
                    value:
                        '${sellerNet.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
                  ),
                  _SellerAmountChip(
                    title: isAr ? 'الوحدات المباعة' : 'Units sold',
                    value: '$soldUnits',
                  ),
                ],
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
    if (user.role != UserRole.seller) {
      return Scaffold(
        backgroundColor: AppTheme.scaffold(context),
        body: Center(
          child: Text(
            context.locale.languageCode == 'ar'
                ? 'هذه الصفحة متاحة للبائعين فقط.'
                : 'This page is available to sellers only.',
          ),
        ),
      );
    }
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
        leading: const AdaptiveAppBarLeading(),
        title: Text('seller.dashboard'.tr()),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/customer/profile', (_) => false),
            icon: const Icon(Icons.swap_horiz),
            label: Text(
              _localizedText(context, 'تغيير إلى عميل', 'Switch to customer'),
            ),
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

class _SellerAmountChip extends StatelessWidget {
  final String title;
  final String value;

  const _SellerAmountChip({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
