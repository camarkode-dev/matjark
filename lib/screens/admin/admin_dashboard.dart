import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' as functions;
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/order_workflow.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/media_upload_service.dart';
import '../../widgets/adaptive_app_bar_leading.dart';
import '../../widgets/remote_image.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  final MediaUploadService _mediaUploadService = MediaUploadService();
  static const int _pageSize = 20;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _pendingSellers = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastPendingSellerDoc;
  bool _loadingPending = false;
  bool _hasMorePending = true;
  String? _pendingSellersError;
  late Future<_AdvancedStats> _advancedStatsFuture;
  late final Stream<int> _usersCountStream;
  late final Stream<int> _sellersCountStream;
  late final Stream<int> _productsCountStream;
  late final Stream<int> _ordersCountStream;
  late final Stream<int> _returnsCountStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _discountCodesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _offersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categoriesStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _returnsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationsStream;
  bool _seedingDemo = false;
  static const int _previewCount = 3;
  int _productsLimit = 20;
  int _ordersLimit = 20;
  int _returnsLimit = 20;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
    _notificationsStream = FirebaseFirestore.instance
        .collection('admin_broadcasts')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _loadPendingSellers(reset: true);
    _advancedStatsFuture = _loadAdvancedStats();
  }

  Stream<int> _count(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) => snap.size);
  }

  void _initializeStreams() {
    final db = FirebaseFirestore.instance;
    _usersCountStream = _count(db.collection('users'));
    _sellersCountStream = _count(
      db.collection('users').where('role', isEqualTo: 'seller'),
    );
    _productsCountStream = _count(db.collection('products'));
    _ordersCountStream = _count(db.collection('orders'));
    _returnsCountStream = _count(db.collection('returns'));
    _usersStream = db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _discountCodesStream = db
        .collection('coupons')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _offersStream = db
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _categoriesStream = db
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _refreshPagedStreams();
  }

  void _refreshPagedStreams() {
    final db = FirebaseFirestore.instance;
    _productsStream = db
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _ordersStream = db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
    _returnsStream = db
        .collection('returns')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _formatFirestoreError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Permission denied while loading admin data.';
      }
      if (error.code == 'failed-precondition') {
        return 'Firestore index is missing for this admin query.';
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
        _formatFirestoreError(error),
        style: const TextStyle(color: Color(0xFF8A1C1C)),
      ),
    );
  }

  Future<void> _refreshAll() async {
    await _loadPendingSellers(reset: true);
    if (!mounted) return;
    setState(() {
      _refreshPagedStreams();
      _advancedStatsFuture = _loadAdvancedStats();
    });
  }

  Future<void> _loadPendingSellers({bool reset = false}) async {
    // prevent parallel loads
    if (_loadingPending) return;
    setState(() => _loadingPending = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('seller_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (!reset && _lastPendingSellerDoc != null && _hasMorePending) {
        query = query.startAfterDocument(_lastPendingSellerDoc!);
      }

      final snap = await query.get();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _pendingSellers.clear();
          _lastPendingSellerDoc = null;
        }
        _pendingSellers.addAll(snap.docs);
        _hasMorePending = snap.docs.length == _pageSize;
        _pendingSellersError = null;
        if (snap.docs.isNotEmpty) {
          _lastPendingSellerDoc = snap.docs.last;
        }
      });
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        try {
          final fallback = await FirebaseFirestore.instance
              .collection('seller_requests')
              .where('status', isEqualTo: 'pending')
              .limit(_pageSize)
              .get();
          if (!mounted) return;
          setState(() {
            if (reset) {
              _pendingSellers.clear();
              _lastPendingSellerDoc = null;
            }
            _pendingSellers
              ..clear()
              ..addAll(fallback.docs);
            _hasMorePending = false;
            _pendingSellersError = null;
          });
        } catch (fallbackError) {
          if (mounted) {
            setState(
              () => _pendingSellersError = _formatFirestoreError(fallbackError),
            );
          }
        }
      } else if (mounted) {
        setState(() => _pendingSellersError = _formatFirestoreError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pendingSellersError = _formatFirestoreError(e));
      }
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _setSellerStatus({
    required String requestId,
    required String uid,
    required String status,
  }) async {
    if (status == 'approved') {
      await _adminService.approveSellerRequest(
        requestId: requestId,
        uid: uid,
        reviewerUid: context.read<AuthProvider>().currentUser?.uid,
      );
    } else {
      await _adminService.rejectSellerRequest(
        requestId: requestId,
        uid: uid,
        reviewerUid: context.read<AuthProvider>().currentUser?.uid,
      );
    }
    await _refreshAll();
  }

  Future<_AdvancedStats> _loadAdvancedStats() async {
    try {
      final db = FirebaseFirestore.instance;
      final orders = await db
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      double totalSales = 0;
      double platformRevenue = 0;
      int active = 0;
      final sellerTotals = <String, double>{};
      final categoryTotals = <String, double>{};

      for (final doc in orders.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        final total = ((data['totalAmount'] ?? 0) as num).toDouble();
        if (isActiveOrderStatus(status)) {
          active++;
        }
        if (normalizeOrderStatus(status) == 'delivered') {
          totalSales += total;
          platformRevenue += ((data['platform_fee'] ??
                      data['commission'] ??
                      (total * 0.02)) as num)
                  .toDouble();
          final sellerId = (data['sellerId'] ?? '').toString();
          if (sellerId.isNotEmpty) {
            sellerTotals[sellerId] = (sellerTotals[sellerId] ?? 0) + total;
          }
        }
        final items = (data['items'] as List?) ?? const [];
        for (final item in items) {
          if (item is! Map) continue;
          final categoryId = (item['categoryId'] ?? 'uncategorized').toString();
          final qty = ((item['quantity'] ?? 1) as num).toDouble();
          final price =
              ((item['unitPrice'] ?? item['price'] ?? 0) as num).toDouble();
          categoryTotals[categoryId] =
              (categoryTotals[categoryId] ?? 0) + qty * price;
        }
      }

      final topSellers = sellerTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return _AdvancedStats(
        totalRevenue: totalSales,
        platformRevenue: platformRevenue,
        activeOrders: active,
        topSellers: topSellers.take(5).toList(),
        topCategories: topCategories.take(5).toList(),
      );
    } catch (e) {
      return const _AdvancedStats(
        totalRevenue: 0,
        platformRevenue: 0,
        activeOrders: 0,
        topSellers: [],
        topCategories: [],
      );
    }
  }

  Future<void> _addDiscountCode() async {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    String type = 'percent';

    final submit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('admin.coupons.add'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: 'admin.coupons.code'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: [
                    DropdownMenuItem(
                      value: 'percent',
                      child: Text('admin.coupons.types.percent'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text('admin.coupons.types.fixed'.tr()),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'admin.coupons.value'.tr(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('common.submit'.tr()),
              ),
            ],
          ),
        );
      },
    );

    if (submit != true) return;
    if (!mounted) return;
    final code = codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final numericValue = double.tryParse(valueController.text.trim()) ?? 0;
    final isArabic = context.locale.languageCode == 'ar';
    await FirebaseFirestore.instance.collection('coupons').doc(code).set({
      'code': code,
      'type': type,
      'value': numericValue,
      'minOrder': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('discount_codes')
        .doc(code)
        .set({
      'code': code,
      'type': type,
      'value': numericValue,
      'minOrder': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final recipientCount = await _adminService.createBroadcastNotification(
      title: isArabic
          ? 'كود خصم جديد: $code'
          : 'New discount code: $code',
      body: isArabic
          ? 'تمت إضافة كود خصم جديد بقيمة ${numericValue.toStringAsFixed(numericValue % 1 == 0 ? 0 : 1)} ${type == 'percent' ? '%' : 'EGP'}.'
          : 'A new discount code worth ${numericValue.toStringAsFixed(numericValue % 1 == 0 ? 0 : 1)} ${type == 'percent' ? '%' : 'EGP'} is now available.',
      type: 'promo.discount_code',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم حفظ كود الخصم وإرساله إلى $recipientCount حساب.'
              : 'Discount code saved and sent to $recipientCount accounts.',
        ),
      ),
    );
  }

  Future<void> _addOffer() async {
    final ar = TextEditingController();
    final en = TextEditingController();
    final discount = TextEditingController(text: '10');
    String? uploadedImageUrl;
    bool uploadingImage = false;
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('admin.offers.add'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ar,
                  decoration: InputDecoration(
                    labelText: 'admin.offers.title_ar'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: en,
                  decoration: InputDecoration(
                    labelText: 'admin.offers.title_en'.tr(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: discount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'admin.offers.discount_percent'.tr(),
                  ),
                ),
                const SizedBox(height: 12),
                if (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty)
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
                            uploadedImageUrl =
                                await _mediaUploadService.uploadOfferImage(
                              fileName: file.name,
                              bytes: file.bytes!,
                            );
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
                        ? 'رفع صورة العرض'
                        : 'Upload offer image',
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
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('common.submit'.tr()),
            ),
          ],
        ),
      ),
    );
    if (submit != true) return;
    if (ar.text.trim().isEmpty ||
        en.text.trim().isEmpty ||
        uploadedImageUrl == null ||
        uploadedImageUrl!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please complete the offer data and upload an image.')),
      );
      return;
    }
    await FirebaseFirestore.instance.collection('offers').add({
      'titleAr': ar.text.trim(),
      'titleEn': en.text.trim(),
      'discountPercent': double.tryParse(discount.text.trim()) ?? 0,
      'imageUrl': uploadedImageUrl!.trim(),
      'bannerUrl': uploadedImageUrl!.trim(),
      'images': <String>[uploadedImageUrl!.trim()],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _seedDemoData() async {
    if (_seedingDemo) return;
    setState(() => _seedingDemo = true);
    try {
      if (kIsWeb) {
        final token =
            await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken();
        final projectId = Firebase.app().options.projectId;
        final uri = Uri.parse(
          'https://us-central1-$projectId.cloudfunctions.net/seedDemoMarketplaceDataHttp',
        );
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, dynamic>{}),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            response.body.isEmpty
                ? 'HTTP ${response.statusCode}'
                : response.body,
          );
        }
      } else {
        // Keep callable path for Android/iOS.
        await functions.FirebaseFunctions.instance
            .httpsCallable(
          'seedDemoMarketplaceData',
        )
            .call({});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('admin.demo.seed_success'.tr())));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin.demo.seed_failed'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _seedingDemo = false);
    }
  }

  Future<void> _setTrackingNumber(
    DocumentReference<Map<String, dynamic>> orderRef,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    final save = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('admin.actions.set_tracking'.tr()),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'admin.actions.tracking_number'.tr(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('admin.actions.save_tracking'.tr()),
              ),
            ],
          ),
        ) ??
        false;
    if (!save) return;
    await orderRef.set({
      'trackingNumber': controller.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _updateOrderStatus(
    DocumentReference<Map<String, dynamic>> orderRef,
    String status,
  ) async {
    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'processing') {
      payload['processingAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'awaiting_shipment') {
      payload['awaitingShipmentAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'shipped') {
      payload['shippedAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'out_for_delivery') {
      payload['outForDeliveryAt'] = FieldValue.serverTimestamp();
    }
    if (status == 'delivered') {
      payload['deliveredAt'] = FieldValue.serverTimestamp();
    }
    await orderRef.set(payload, SetOptions(merge: true));
  }

  Future<void> _toggleProductApproval(
    DocumentReference<Map<String, dynamic>> productRef,
    bool approved,
  ) async {
    await productRef.set({
      'isApproved': approved,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteProduct(
    DocumentReference<Map<String, dynamic>> productRef,
  ) async {
    await productRef.delete();
  }

  bool _isProtectedAdminProfile(Map<String, dynamic> data) {
    return _adminService
        .isProtectedAdminEmail((data['email'] ?? '').toString());
  }

  String _effectiveRole(Map<String, dynamic> data) {
    if (_isProtectedAdminProfile(data)) {
      return 'admin';
    }
    return (data['role'] ?? 'customer').toString();
  }

  bool _isSellerAccount(Map<String, dynamic> data) {
    final role = _effectiveRole(data);
    final sellerRequestStatus = (data['sellerRequestStatus'] ?? '').toString();
    return role == 'seller' || sellerRequestStatus == 'approved';
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

  Future<void> _hideOrderForAdmin(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await _runAdminAction(
      () => doc.reference.set({
        'hiddenForAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      successMessage: 'Order hidden from admin list.',
    );
  }

  Future<void> _hideReturnForAdmin(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await _runAdminAction(
      () => doc.reference.set({
        'hiddenForAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      successMessage: 'Return request hidden from admin list.',
    );
  }

  Future<void> _runAdminAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();
      if (!mounted) return;
      if (successMessage != null && successMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
      await _refreshAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatFirestoreError(error))),
      );
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                style: destructive
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('common.submit'.tr()),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openExternalUrl(String? url) async {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  bool _isImageUrl(String? url) {
    final normalized = (url ?? '').toLowerCase();
    return normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.contains('image');
  }

  Future<void> _openProductForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final categoriesSnapshot = await FirebaseFirestore.instance
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').limit(100).get();
    final sellerDocs = usersSnapshot.docs.where((userDoc) {
      final userData = userDoc.data();
      final role = _effectiveRole(userData);
      return role == 'seller' || role == 'admin';
    }).toList();

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
    String? uploadedImageUrl = ((data['images'] as List?)?.isNotEmpty ?? false)
        ? (data['images'] as List).first.toString()
        : null;
    bool uploadingImage = false;
    String? selectedCategoryId = (data['categoryId'] ?? '').toString();
    if (selectedCategoryId.isEmpty) {
      selectedCategoryId = null;
    }
    String? selectedSellerId = (data['sellerId'] ?? '').toString();
    if (selectedSellerId.isEmpty && sellerDocs.isNotEmpty) {
      selectedSellerId = sellerDocs.first.id;
    }
    if (!mounted) return;

    final save = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(doc == null ? 'Add product' : 'Edit product'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleAr,
                        decoration: const InputDecoration(
                          labelText: 'Arabic title',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleEn,
                        decoration: const InputDecoration(
                          labelText: 'English title',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionAr,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Arabic description',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionEn,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'English description',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSellerId,
                        decoration: const InputDecoration(
                          labelText: 'Seller',
                        ),
                        items: sellerDocs
                            .map(
                              (sellerDoc) => DropdownMenuItem<String>(
                                value: sellerDoc.id,
                                child: Text(
                                  '${((sellerDoc.data()['name'] ?? sellerDoc.data()['email']) ?? sellerDoc.id)} (${sellerDoc.id.substring(0, 6)})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedSellerId = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categoriesSnapshot.docs
                            .map(
                              (categoryDoc) => DropdownMenuItem<String>(
                                value: categoryDoc.id,
                                child: Text(
                                  ((categoryDoc.data()['nameAr'] ??
                                              categoryDoc.data()['nameEn']) ??
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
                        decoration: const InputDecoration(
                          labelText: 'Selling price',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
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
                                final ownerId = selectedSellerId;
                                if (ownerId == null || ownerId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please select a seller first.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
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
                                  uploadedImageUrl = await _mediaUploadService
                                      .uploadProductImage(
                                    ownerId: ownerId,
                                    fileName: file.name,
                                    bytes: file.bytes!,
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setDialogState(
                                        () => uploadingImage = false);
                                  }
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
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
        parsedStock < 0 ||
        (selectedSellerId ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please complete product data correctly.')),
      );
      return;
    }

    await _runAdminAction(
      () => _adminService.upsertProduct(
        productId: doc?.id,
        data: {
          'titleAr': titleAr.text.trim(),
          'titleEn': titleEn.text.trim(),
          'descriptionAr': descriptionAr.text.trim(),
          'descriptionEn': descriptionEn.text.trim(),
          'costPrice': parsedPrice,
          'sellingPrice': parsedPrice,
          'commissionAmount':
              double.parse((parsedPrice * 0.02).toStringAsFixed(2)),
          'stock': parsedStock,
          'images': uploadedImageUrl == null || uploadedImageUrl!.trim().isEmpty
              ? <String>[]
              : <String>[uploadedImageUrl!.trim()],
          'sellerId': selectedSellerId,
          'supplierId': data['supplierId'],
          'categoryId': selectedCategoryId,
          'isApproved': true,
          'rating': (data['rating'] ?? 0) as num,
          'salesCount': (data['salesCount'] ?? 0) as num,
        },
      ),
      successMessage: doc == null ? 'Product added.' : 'Product updated.',
    );
  }

  Future<void> _openCategoryForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final nameAr = TextEditingController(
      text: (data['nameAr'] ?? '').toString(),
    );
    final nameEn = TextEditingController(
      text: (data['nameEn'] ?? '').toString(),
    );
    String? uploadedImageUrl = (data['imageUrl'] ?? '').toString().trim();
    if (uploadedImageUrl.isEmpty) {
      uploadedImageUrl = null;
    }
    bool uploadingImage = false;
    final save = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(doc == null ? 'Add category' : 'Edit category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameAr,
                      decoration:
                          const InputDecoration(labelText: 'Arabic name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameEn,
                      decoration:
                          const InputDecoration(labelText: 'English name'),
                    ),
                    const SizedBox(height: 12),
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
                                uploadedImageUrl = await _mediaUploadService
                                    .uploadCategoryImage(
                                  fileName: file.name,
                                  bytes: file.bytes!,
                                );
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
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('common.submit'.tr()),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!save) return;
    if (nameAr.text.trim().isEmpty || nameEn.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please complete category data correctly.')),
      );
      return;
    }
    await _runAdminAction(
      () => _adminService.upsertCategory(
        categoryId: doc?.id,
        nameAr: nameAr.text.trim(),
        nameEn: nameEn.text.trim(),
        imageUrl: uploadedImageUrl,
      ),
      successMessage: doc == null ? 'Category added.' : 'Category updated.',
    );
  }

  Future<void> _seedDefaultCategories() async {
    final isArabic = context.locale.languageCode == 'ar';
    final confirmed = await _confirmAction(
      title: isArabic ? 'إضافة أقسام جاهزة' : 'Seed default categories',
      message: isArabic
          ? 'سيتم إنشاء مجموعة أقسام جاهزة مثل الأحذية، الأزياء، الإلكترونيات، المنزل والمطبخ وغيرها. العملية آمنة ويمكن تكرارها.'
          : 'This will create a ready-to-use category set including shoes, fashion, electronics, home, kitchen, and more. The operation is safe and repeatable.',
    );
    if (!confirmed) return;
    await _runAdminAction(
      () async {
        await _adminService.seedDefaultCategories();
      },
      successMessage:
          isArabic ? 'تمت إضافة الأقسام الجاهزة.' : 'Default categories added.',
    );
  }

  Future<void> _openBroadcastNotificationForm({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};
    final title = TextEditingController(text: (data['title'] ?? '').toString());
    final body = TextEditingController(text: (data['body'] ?? '').toString());
    final save = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title:
                Text(doc == null ? 'Send notification' : 'Edit notification'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Notification title',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: body,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notification message',
                    ),
                  ),
                ],
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
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and message.')),
      );
      return;
    }

    var recipientCount = 0;
    await _runAdminAction(() async {
      if (doc == null) {
        recipientCount = await _adminService.createBroadcastNotification(
          title: title.text.trim(),
          body: body.text.trim(),
        );
      } else {
        await _adminService.updateBroadcastNotification(
          broadcastId: doc.id,
          title: title.text.trim(),
          body: body.text.trim(),
        );
      }
    },
        successMessage: doc == null
            ? 'Notification sent to customers and sellers.'
            : 'Notification updated.');
    if (!mounted || doc != null || recipientCount == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delivered to $recipientCount accounts.')),
    );
  }

  Future<void> _overrideReturnStatus({
    required QueryDocumentSnapshot<Map<String, dynamic>> returnDoc,
    required bool approve,
  }) async {
    final status = approve ? 'admin_approved' : 'admin_rejected';
    final data = returnDoc.data();
    final orderId = (data['orderId'] ?? '').toString();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
        returnDoc.reference,
        {
          'status': status,
          'adminDecision': approve ? 'approved' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    if (orderId.isNotEmpty) {
      final orderUpdate = <String, dynamic>{
        'returnRequestStatus': status,
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isAr = context.locale.languageCode == 'ar';
    if (!auth.isAdmin && user?.role != null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffold(context),
        body: Center(
          child: Text(
            context.locale.languageCode == 'ar'
                ? 'هذه الصفحة متاحة للإدارة فقط.'
                : 'This page is available to administrators only.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(),
        title: Text('admin.dashboard'.tr()),
        actions: [
          IconButton(
            tooltip: 'admin.demo.seed_data'.tr(),
            onPressed: _seedingDemo ? null : _seedDemoData,
            icon: _seedingDemo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.data_object),
          ),
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: auth.signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Text(
              'admin.control_panel'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricTile(
                title: 'admin.metrics.users'.tr(),
                icon: Icons.people_alt_outlined,
                stream: _usersCountStream,
              ),
              _MetricTile(
                title: 'admin.metrics.sellers'.tr(),
                icon: Icons.storefront_outlined,
                stream: _sellersCountStream,
              ),
              _MetricTile(
                title: 'admin.metrics.products'.tr(),
                icon: Icons.inventory_2_outlined,
                stream: _productsCountStream,
              ),
              _MetricTile(
                title: 'admin.metrics.orders'.tr(),
                icon: Icons.receipt_long_outlined,
                stream: _ordersCountStream,
              ),
              _MetricTile(
                title: 'admin.metrics.returns'.tr(),
                icon: Icons.assignment_return_outlined,
                stream: _returnsCountStream,
              ),
              _FutureAmountMetricTile(
                title: isAr ? 'إجمالي المبيعات' : 'Total sales',
                icon: Icons.payments_outlined,
                future: _advancedStatsFuture,
                selector: (stats) => stats.totalRevenue,
              ),
              _FutureAmountMetricTile(
                title: isAr ? 'إيراد المنصة 2%' : 'Platform revenue 2%',
                icon: Icons.trending_up_outlined,
                future: _advancedStatsFuture,
                selector: (stats) => stats.platformRevenue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAdvancedStatsCard(),
          const SizedBox(height: 16),
          _buildUsersManagementCardV2(),
          const SizedBox(height: 16),
          _buildPendingSellersCard(),
          const SizedBox(height: 16),
          _buildProductsModerationCardV2(),
          const SizedBox(height: 16),
          _buildOrdersManagementCardV2(),
          const SizedBox(height: 16),
          _buildReturnsOverrideCardV2(),
          const SizedBox(height: 16),
          _buildDiscountCodesCardV2(),
          const SizedBox(height: 16),
          _buildCategoriesCardV2(),
          const SizedBox(height: 16),
          _buildOffersCardV2(),
          const SizedBox(height: 16),
          _buildNotificationsCardV2(),
        ],
      ),
    );
  }

  Widget _buildAdvancedStatsCard() {
    return _sectionPanel(
      child: FutureBuilder<_AdvancedStats>(
        future: _advancedStatsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null) return Text('errors.no_data'.tr());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'admin.sections.advanced_stats'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${context.locale.languageCode == 'ar' ? 'إجمالي المبيعات' : 'Total sales'}: ${data.totalRevenue.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
              ),
              Text(
                '${context.locale.languageCode == 'ar' ? 'إيراد المنصة 2%' : 'Platform revenue 2%'}: ${data.platformRevenue.toStringAsFixed(2)} ${'common.currency_egp'.tr()}',
              ),
              Text('${'admin.stats.active_orders'.tr()}: ${data.activeOrders}'),
              const SizedBox(height: 8),
              Text('admin.stats.sales_per_seller'.tr()),
              ...data.topSellers.map(
                (e) => Text('${e.key}: ${e.value.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 8),
              Text('admin.stats.revenue_by_category'.tr()),
              ...data.topCategories.map(
                (e) => Text('${e.key}: ${e.value.toStringAsFixed(2)}'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: child,
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _previewDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.take(_previewCount).toList();
  }

  Widget _buildSectionTitleBar({
    required String title,
    required VoidCallback onShowAll,
    List<Widget> actions = const <Widget>[],
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...actions,
        TextButton(
          onPressed: onShowAll,
          child: Text(
            context.locale.languageCode == 'ar' ? 'إظهار الكل' : 'Show all',
          ),
        ),
      ],
    );
  }

  void _openAdminRecordsView({
    required String title,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String searchHint,
    required String Function(QueryDocumentSnapshot<Map<String, dynamic>>) searchTextBuilder,
    required Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminRecordsScreen(
          title: title,
          docs: docs,
          searchHint: searchHint,
          searchTextBuilder: searchTextBuilder,
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }

  Widget _buildUserTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final role = _effectiveRole(d);
    final status = (d['status'] ?? 'approved').toString();
    final email = (d['email'] ?? '').toString();
    final protectedAdmin = _isProtectedAdminProfile(d);
    final sellerAccount = _isSellerAccount(d);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text((d['name'] ?? d['email'] ?? doc.id).toString()),
      subtitle: Text('$role - $status'),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (!protectedAdmin && status != 'approved')
            IconButton(
              tooltip: 'Activate',
              onPressed: () => _runAdminAction(
                () => _adminService.reactivateUser(uid: doc.id),
                successMessage: 'User activated.',
              ),
              icon: const Icon(Icons.check_circle_outline),
            ),
          if (!protectedAdmin && status != 'suspended')
            IconButton(
              tooltip: 'admin.actions.suspend'.tr(),
              onPressed: () => _runAdminAction(
                () => _adminService.suspendUser(
                  uid: doc.id,
                  email: email,
                ),
                successMessage: 'User suspended.',
              ),
              icon: const Icon(Icons.block_outlined),
            ),
          if (!protectedAdmin && sellerAccount)
            IconButton(
              tooltip: 'admin.actions.delete'.tr(),
              onPressed: () async {
                final confirmed = await _confirmAction(
                  title: 'Delete seller account',
                  message:
                      'This will remove the seller profile, products, and pending requests.',
                  destructive: true,
                );
                if (!confirmed) return;
                await _runAdminAction(
                  () => _adminService.deleteSellerAccount(
                    uid: doc.id,
                    email: email,
                  ),
                  successMessage: 'Seller account deleted.',
                );
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  Widget _buildProductAdminTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final ar = context.locale.languageCode == 'ar';
    final title = (ar ? d['titleAr'] : d['titleEn']) ??
        d['titleEn'] ??
        d['titleAr'] ??
        doc.id;
    final imageUrl = ((d['images'] as List?)?.isNotEmpty ?? false)
        ? (d['images'] as List).first.toString()
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panelSoft(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RemoteThumbnail(url: imageUrl),
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
                const SizedBox(height: 4),
                Text('${'admin.sections.seller_prefix'.tr()}${d['sellerId'] ?? '-'}'),
                Text(
                  'Price: ${d['sellingPrice'] ?? 0} - Stock: ${d['stock'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Switch(
                value: d['isApproved'] == true,
                onChanged: (value) => _runAdminAction(
                  () => _toggleProductApproval(doc.reference, value),
                  successMessage:
                      value ? 'Product approved.' : 'Product hidden.',
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _openProductForm(doc: doc),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'admin.actions.delete'.tr(),
                    onPressed: () async {
                      final confirmed = await _confirmAction(
                        title: 'Delete product',
                        message: 'This will permanently delete the product.',
                        destructive: true,
                      );
                      if (!confirmed) return;
                      await _runAdminAction(
                        () => _deleteProduct(doc.reference),
                        successMessage: 'Product deleted.',
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderAdminTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    const statuses = orderManagementStatuses;
    final d = doc.data();
    final status = normalizeOrderStatus((d['status'] ?? 'pending').toString());
    final tracking = (d['trackingNumber'] ?? '').toString();
    final canHide = status == 'delivered' || status == 'returned';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${'admin.sections.order_prefix'.tr()}${doc.id.substring(0, 8)}',
      ),
      subtitle: Text(
        '${'admin.sections.customer_prefix'.tr()}${_customerName(d)}',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          DropdownButton<String>(
            value: statuses.contains(status) ? status : statuses.first,
            items: statuses
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      orderStatusLabel(
                        s,
                        isArabic: context.locale.languageCode == 'ar',
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              _updateOrderStatus(doc.reference, v);
            },
          ),
          IconButton(
            tooltip:
                tracking.isEmpty ? 'admin.actions.set_tracking'.tr() : tracking,
            onPressed: () => _setTrackingNumber(doc.reference, tracking),
            icon: const Icon(Icons.local_shipping_outlined),
          ),
          if (canHide)
            IconButton(
              tooltip: 'Hide order',
              onPressed: () => _hideOrderForAdmin(doc),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnAdminTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = (d['status'] ?? 'pending_seller_review').toString();
    final canHide = status == 'returned_completed' ||
        status == 'seller_rejected';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${'admin.sections.return_prefix'.tr()}${doc.id.substring(0, 8)}',
      ),
      subtitle: Text(
        returnStatusLabel(
          status,
          isArabic: context.locale.languageCode == 'ar',
        ),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (canHide)
            IconButton(
              tooltip: 'Hide return',
              onPressed: () => _hideReturnForAdmin(doc),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscountCodeTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text((d['code'] ?? doc.id).toString()),
      subtitle: Text('${d['type'] ?? 'percent'}: ${d['value'] ?? 0}'),
      value: d['isActive'] == true,
      onChanged: (v) => doc.reference.set({
        'isActive': v,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }

  Widget _buildOfferAdminTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final isArabic = context.locale.languageCode == 'ar';
    final title = (isArabic ? d['titleAr'] : d['titleEn']) ??
        d['titleEn'] ??
        d['titleAr'] ??
        doc.id;
    final imageUrl = (d['imageUrl'] ?? '').toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _RemoteThumbnail(
        url: imageUrl.isEmpty ? null : imageUrl,
        size: 40,
      ),
      title: Text(title.toString()),
      subtitle: Text(
        '${'admin.offers.discount_percent'.tr()}: ${d['discountPercent'] ?? 0}%',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          Switch(
            value: d['isActive'] == true,
            onChanged: (v) => doc.reference.set({
              'isActive': v,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)),
          ),
          IconButton(
            tooltip: 'admin.actions.delete'.tr(),
            onPressed: () async {
              final confirmed = await _confirmAction(
                title: 'Delete offer',
                message: 'This will permanently delete the offer.',
                destructive: true,
              );
              if (!confirmed) return;
              await _runAdminAction(
                () => doc.reference.delete(),
                successMessage: 'Offer deleted.',
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAdminTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final isArabic = context.locale.languageCode == 'ar';
    final title = (isArabic ? d['nameAr'] : d['nameEn']) ??
        d['nameEn'] ??
        d['nameAr'] ??
        doc.id;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title.toString()),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openCategoryForm(doc: doc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await _confirmAction(
                title: 'Delete category',
                message:
                    'This will remove the category and clear it from assigned products.',
                destructive: true,
              );
              if (!confirmed) return;
              await _runAdminAction(
                () => _adminService.deleteCategory(doc.id),
                successMessage: 'Category deleted.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationAdminTile(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text((d['title'] ?? d['type'] ?? '').toString()),
      subtitle: Text((d['body'] ?? '').toString()),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openBroadcastNotificationForm(doc: doc),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'admin.actions.delete'.tr(),
            onPressed: () async {
              final confirmed = await _confirmAction(
                title: 'Delete notification',
                message:
                    'This will remove the notification from all customer and seller accounts.',
                destructive: true,
              );
              if (!confirmed) return;
              await _runAdminAction(
                () => _adminService.deleteBroadcastNotification(doc.id),
                successMessage: 'Notification deleted.',
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSellersCard() {
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.sections.pending_sellers'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_pendingSellersError != null)
            _buildQueryError(_pendingSellersError!),
          if (_pendingSellersError != null) const SizedBox(height: 8),
          if (_pendingSellersError == null &&
              _pendingSellers.isEmpty &&
              !_loadingPending)
            Text('admin.sections.no_pending_sellers'.tr()),
          ..._pendingSellers.map((doc) {
            final d = doc.data();
            final uid = (d['uid'] ?? '').toString();
            final merchant =
                (d['merchant_name'] ?? d['ownerName'] ?? '').toString();
            final store = (d['store_name'] ?? d['storeName'] ?? '').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.panelSoft(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.isNotEmpty
                        ? merchant
                        : (d['email'] ?? 'admin.sections.unnamed_seller'.tr())
                            .toString(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.isNotEmpty ? '$store - $uid' : uid,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if ((d['email'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      (d['email'] ?? '').toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SellerDocumentButton(
                        label: 'National ID',
                        url: (d['national_id_image'] ?? '').toString(),
                        isImage: _isImageUrl(
                          (d['national_id_image'] ?? '').toString(),
                        ),
                        onOpen: _openExternalUrl,
                      ),
                      _SellerDocumentButton(
                        label: 'Commercial Register',
                        url: (d['commercial_register_image'] ?? '').toString(),
                        isImage: _isImageUrl(
                          (d['commercial_register_image'] ?? '').toString(),
                        ),
                        onOpen: _openExternalUrl,
                      ),
                      _SellerDocumentButton(
                        label: 'Tax Card',
                        url: (d['tax_card_image'] ?? '').toString(),
                        isImage: _isImageUrl(
                          (d['tax_card_image'] ?? '').toString(),
                        ),
                        onOpen: _openExternalUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () => _runAdminAction(
                                  () => _setSellerStatus(
                                    requestId: doc.id,
                                    uid: uid,
                                    status: 'rejected',
                                  ),
                                  successMessage: 'Seller request rejected.',
                                ),
                        icon: const Icon(Icons.close),
                        label: Text('admin.actions.reject'.tr()),
                      ),
                      ElevatedButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () => _runAdminAction(
                                  () => _setSellerStatus(
                                    requestId: doc.id,
                                    uid: uid,
                                    status: 'approved',
                                  ),
                                  successMessage: 'Seller request approved.',
                                ),
                        icon: const Icon(Icons.check),
                        label: Text('admin.actions.approve'.tr()),
                      ),
                      TextButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () async {
                                final confirmed = await _confirmAction(
                                  title: 'Delete seller request',
                                  message:
                                      'This will remove the pending seller request.',
                                  destructive: true,
                                );
                                if (!confirmed) return;
                                await _runAdminAction(
                                  () => _adminService.deleteSellerRequest(
                                    requestId: doc.id,
                                    uid: uid,
                                  ),
                                  successMessage: 'Seller request deleted.',
                                );
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: Text('admin.actions.delete'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          if (_loadingPending) const Center(child: CircularProgressIndicator()),
          if (_hasMorePending && !_loadingPending)
            TextButton.icon(
              onPressed: () => _loadPendingSellers(),
              icon: const Icon(Icons.expand_more),
              label: Text('admin.sections.load_more'.tr()),
            ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildUsersManagementCard() {
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Users management',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('errors.no_data'.tr());
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data();
                  final role = _effectiveRole(d);
                  final status = (d['status'] ?? 'approved').toString();
                  final email = (d['email'] ?? '').toString();
                  final protectedAdmin = _isProtectedAdminProfile(d);
                  final sellerAccount = _isSellerAccount(d);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((d['name'] ?? d['email'] ?? doc.id).toString()),
                    subtitle: Text('$role · $status'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        if (!protectedAdmin && status != 'approved')
                          IconButton(
                            tooltip: 'Activate',
                            onPressed: () => _runAdminAction(
                              () => _adminService.reactivateUser(uid: doc.id),
                              successMessage: 'User activated.',
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                        if (!protectedAdmin && status != 'suspended')
                          IconButton(
                            tooltip: 'admin.actions.suspend'.tr(),
                            onPressed: () => _runAdminAction(
                              () => _adminService.suspendUser(
                                uid: doc.id,
                                email: email,
                              ),
                              successMessage: 'User suspended.',
                            ),
                            icon: const Icon(Icons.block_outlined),
                          ),
                        if (!protectedAdmin && sellerAccount)
                          IconButton(
                            tooltip: 'admin.actions.delete'.tr(),
                            onPressed: () async {
                              final confirmed = await _confirmAction(
                                title: 'Delete seller account',
                                message:
                                    'This will remove the seller profile, products, and pending requests.',
                                destructive: true,
                              );
                              if (!confirmed) return;
                              await _runAdminAction(
                                () => _adminService.deleteSellerAccount(
                                  uid: doc.id,
                                  email: email,
                                ),
                                successMessage: 'Seller account deleted.',
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProductsModerationCard() {
    final ar = context.locale.languageCode == 'ar';
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.sections.products_moderation'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openProductForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _productsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('admin.sections.no_products'.tr());
              }
              return Column(
                children: [
                  ...docs.map((doc) {
                    final d = doc.data();
                    final title = (ar ? d['titleAr'] : d['titleEn']) ??
                        d['titleEn'] ??
                        d['titleAr'] ??
                        doc.id;
                    final imageUrl =
                        ((d['images'] as List?)?.isNotEmpty ?? false)
                            ? (d['images'] as List).first.toString()
                            : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.panelSoft(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RemoteThumbnail(url: imageUrl),
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
                                const SizedBox(height: 4),
                                Text(
                                  '${'admin.sections.seller_prefix'.tr()}${d['sellerId'] ?? '-'}',
                                ),
                                Text(
                                  'Price: ${d['sellingPrice'] ?? 0} - Stock: ${d['stock'] ?? 0}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Switch(
                                value: d['isApproved'] == true,
                                onChanged: (value) => _runAdminAction(
                                  () => _toggleProductApproval(
                                    doc.reference,
                                    value,
                                  ),
                                  successMessage: value
                                      ? 'Product approved.'
                                      : 'Product hidden.',
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: () => _openProductForm(doc: doc),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'admin.actions.delete'.tr(),
                                    onPressed: () async {
                                      final confirmed = await _confirmAction(
                                        title: 'Delete product',
                                        message:
                                            'This will permanently delete the product.',
                                        destructive: true,
                                      );
                                      if (!confirmed) return;
                                      await _runAdminAction(
                                        () => _deleteProduct(doc.reference),
                                        successMessage: 'Product deleted.',
                                      );
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  if (docs.length >= _productsLimit)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _productsLimit += _pageSize;
                        _refreshPagedStreams();
                      }),
                      icon: const Icon(Icons.expand_more),
                      label: Text('admin.sections.load_more'.tr()),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOrdersManagementCard() {
    const statuses = orderManagementStatuses;
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.sections.orders_management'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _ordersStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('admin.sections.no_orders'.tr());
              }
              return Column(
                children: [
                  ...docs.map((doc) {
                    final d = doc.data();
                    final status = normalizeOrderStatus(
                      (d['status'] ?? 'pending').toString(),
                    );
                    final tracking = (d['trackingNumber'] ?? '').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${'admin.sections.order_prefix'.tr()}${doc.id.substring(0, 8)}',
                      ),
                      subtitle: Text(
                        '${'admin.sections.customer_prefix'.tr()}${d['customerId'] ?? '-'}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          DropdownButton<String>(
                            value: statuses.contains(status)
                                ? status
                                : statuses.first,
                            items: statuses
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
                              _updateOrderStatus(doc.reference, v);
                            },
                          ),
                          IconButton(
                            tooltip: tracking.isEmpty
                                ? 'admin.actions.set_tracking'.tr()
                                : tracking,
                            onPressed: () =>
                                _setTrackingNumber(doc.reference, tracking),
                            icon: const Icon(Icons.local_shipping_outlined),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (docs.length >= _ordersLimit)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _ordersLimit += _pageSize;
                        _refreshPagedStreams();
                      }),
                      icon: const Icon(Icons.expand_more),
                      label: Text('admin.sections.load_more'.tr()),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildReturnsOverrideCard() {
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.sections.returns_override'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _returnsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('admin.sections.no_returns'.tr());
              }
              return Column(
                children: [
                  ...docs.map((doc) {
                    final d = doc.data();
                    final status =
                        (d['status'] ?? 'pending_seller_review').toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${'admin.sections.return_prefix'.tr()}${doc.id.substring(0, 8)}',
                      ),
                      subtitle: Text('admin.returns.statuses.$status'.tr()),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => _overrideReturnStatus(
                              returnDoc: doc,
                              approve: false,
                            ),
                            child: Text('admin.actions.reject'.tr()),
                          ),
                          ElevatedButton(
                            onPressed: () => _overrideReturnStatus(
                              returnDoc: doc,
                              approve: true,
                            ),
                            child: Text('admin.actions.approve'.tr()),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (docs.length >= _returnsLimit)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _returnsLimit += _pageSize;
                        _refreshPagedStreams();
                      }),
                      icon: const Icon(Icons.expand_more),
                      label: Text('admin.sections.load_more'.tr()),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDiscountCodesCard() {
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.sections.discount_codes'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton(
                onPressed: _addDiscountCode,
                child: Text('admin.coupons.add'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _discountCodesStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('admin.coupons.none'.tr());
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data();
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((d['code'] ?? doc.id).toString()),
                    subtitle: Text(
                      '${d['type'] ?? 'percent'}: ${d['value'] ?? 0}',
                    ),
                    value: d['isActive'] == true,
                    onChanged: (v) => doc.reference.set({
                      'isActive': v,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildOffersCard() {
    final isArabic = context.locale.languageCode == 'ar';
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.sections.offers_promotions'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton(
                onPressed: _addOffer,
                child: Text('admin.offers.add'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _offersStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('admin.offers.none'.tr());
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data();
                  final title = (isArabic ? d['titleAr'] : d['titleEn']) ??
                      d['titleEn'] ??
                      d['titleAr'] ??
                      doc.id;
                  final imageUrl = (d['imageUrl'] ?? '').toString();
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: _RemoteThumbnail(
                      url: imageUrl.isEmpty ? null : imageUrl,
                      size: 40,
                    ),
                    title: Text(title.toString()),
                    subtitle: Text(
                      '${'admin.offers.discount_percent'.tr()}: ${d['discountPercent'] ?? 0}%',
                    ),
                    value: d['isActive'] == true,
                    onChanged: (v) => doc.reference.set({
                      'isActive': v,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCategoriesCard() {
    final isArabic = context.locale.languageCode == 'ar';
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isArabic ? 'الأقسام' : 'Categories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _seedDefaultCategories,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(isArabic ? 'أقسام جاهزة' : 'Quick setup'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _openCategoryForm(),
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _categoriesStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('errors.no_data'.tr()),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _seedDefaultCategories,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        isArabic
                            ? 'إضافة الأقسام الجاهزة'
                            : 'Add default categories',
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data();
                  final title = (isArabic ? d['nameAr'] : d['nameEn']) ??
                      d['nameEn'] ??
                      d['nameAr'] ??
                      doc.id;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title.toString()),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openCategoryForm(doc: doc),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await _confirmAction(
                              title: 'Delete category',
                              message:
                                  'This will remove the category and clear it from assigned products.',
                              destructive: true,
                            );
                            if (!confirmed) return;
                            await _runAdminAction(
                              () => _adminService.deleteCategory(doc.id),
                              successMessage: 'Category deleted.',
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildNotificationsCard() {
    if (_notificationsStream == null) return const SizedBox.shrink();
    return _sectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.sections.notifications_panel'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openBroadcastNotificationForm,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notificationsStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return _buildQueryError(snap.error!);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('notifications.none'.tr());
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((d['title'] ?? d['type'] ?? '').toString()),
                    subtitle: Text((d['body'] ?? '').toString()),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _openBroadcastNotificationForm(
                            doc: doc,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'admin.actions.delete'.tr(),
                          onPressed: () async {
                            final confirmed = await _confirmAction(
                              title: 'Delete notification',
                              message:
                                  'This will remove the notification from all customer and seller accounts.',
                              destructive: true,
                            );
                            if (!confirmed) return;
                            await _runAdminAction(
                              () => _adminService.deleteBroadcastNotification(
                                doc.id,
                              ),
                              successMessage: 'Notification deleted.',
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsersManagementCardV2() {
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Text('errors.no_data'.tr());
          }
          final docs = _previewDocs(allDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'Users management',
                onShowAll: () => _openAdminRecordsView(
                  title: 'Users management',
                  docs: allDocs,
                  searchHint: 'Search users',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${d['name'] ?? ''} ${d['email'] ?? ''} ${_effectiveRole(d)} ${d['status'] ?? ''}';
                  },
                  itemBuilder: _buildUserTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildUserTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductsModerationCardV2() {
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Text('admin.sections.no_products'.tr());
          }
          final docs = _previewDocs(allDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'admin.sections.products_moderation'.tr(),
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => _openProductForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                  const SizedBox(width: 8),
                ],
                onShowAll: () => _openAdminRecordsView(
                  title: 'admin.sections.products_moderation'.tr(),
                  docs: allDocs,
                  searchHint: 'Search products',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${d['titleAr'] ?? ''} ${d['titleEn'] ?? ''} ${d['sellerId'] ?? ''} ${d['categoryId'] ?? ''}';
                  },
                  itemBuilder: _buildProductAdminTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildProductAdminTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersManagementCardV2() {
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          final visibleDocs = allDocs
              .where((doc) => doc.data()['hiddenForAdmin'] != true)
              .toList();
          if (visibleDocs.isEmpty) {
            return Text('admin.sections.no_orders'.tr());
          }
          final docs = _previewDocs(visibleDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'admin.sections.orders_management'.tr(),
                onShowAll: () => _openAdminRecordsView(
                  title: 'admin.sections.orders_management'.tr(),
                  docs: visibleDocs,
                  searchHint: 'Search orders',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${doc.id} ${_customerName(d)} ${d['sellerId'] ?? ''} ${d['status'] ?? ''}';
                  },
                  itemBuilder: _buildOrderAdminTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildOrderAdminTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReturnsOverrideCardV2() {
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _returnsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          final visibleDocs = allDocs
              .where((doc) => doc.data()['hiddenForAdmin'] != true)
              .toList();
          if (visibleDocs.isEmpty) {
            return Text('admin.sections.no_returns'.tr());
          }
          final docs = _previewDocs(visibleDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'admin.sections.returns_override'.tr(),
                onShowAll: () => _openAdminRecordsView(
                  title: 'admin.sections.returns_override'.tr(),
                  docs: visibleDocs,
                  searchHint: 'Search returns',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${doc.id} ${d['orderId'] ?? ''} ${d['sellerId'] ?? ''} ${d['status'] ?? ''} ${d['reason'] ?? ''}';
                  },
                  itemBuilder: _buildReturnAdminTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildReturnAdminTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiscountCodesCardV2() {
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _discountCodesStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Text('admin.coupons.none'.tr());
          }
          final docs = _previewDocs(allDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'admin.sections.discount_codes'.tr(),
                actions: [
                  ElevatedButton(
                    onPressed: _addDiscountCode,
                    child: Text('admin.coupons.add'.tr()),
                  ),
                  const SizedBox(width: 8),
                ],
                onShowAll: () => _openAdminRecordsView(
                  title: 'admin.sections.discount_codes'.tr(),
                  docs: allDocs,
                  searchHint: 'Search codes',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${d['code'] ?? ''} ${d['type'] ?? ''} ${d['value'] ?? ''}';
                  },
                  itemBuilder: _buildDiscountCodeTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildDiscountCodeTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOffersCardV2() {
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _offersStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('admin.offers.none'.tr()),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _addOffer,
                  child: Text('admin.offers.add'.tr()),
                ),
              ],
            );
          }
          final docs = _previewDocs(allDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'admin.sections.offers_promotions'.tr(),
                actions: [
                  ElevatedButton(
                    onPressed: _addOffer,
                    child: Text('admin.offers.add'.tr()),
                  ),
                  const SizedBox(width: 8),
                ],
                onShowAll: () => _openAdminRecordsView(
                  title: 'admin.sections.offers_promotions'.tr(),
                  docs: allDocs,
                  searchHint: 'Search offers',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${d['titleAr'] ?? ''} ${d['titleEn'] ?? ''} ${d['discountPercent'] ?? ''}';
                  },
                  itemBuilder: _buildOfferAdminTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildOfferAdminTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoriesCardV2() {
    final isArabic = context.locale.languageCode == 'ar';
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _categoriesStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('errors.no_data'.tr()),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _seedDefaultCategories,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    isArabic ? 'إضافة الأقسام الجاهزة' : 'Add default categories',
                  ),
                ),
              ],
            );
          }
          final docs = _previewDocs(allDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: isArabic ? 'الأقسام' : 'Categories',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _seedDefaultCategories,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(isArabic ? 'أقسام جاهزة' : 'Quick setup'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _openCategoryForm(),
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 8),
                ],
                onShowAll: () => _openAdminRecordsView(
                  title: isArabic ? 'الأقسام' : 'Categories',
                  docs: allDocs,
                  searchHint: isArabic ? 'ابحث في الأقسام' : 'Search categories',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${d['nameAr'] ?? ''} ${d['nameEn'] ?? ''}';
                  },
                  itemBuilder: _buildCategoryAdminTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildCategoryAdminTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationsCardV2() {
    if (_notificationsStream == null) return const SizedBox.shrink();
    return _sectionPanel(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _buildQueryError(snap.error!);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allDocs = snap.data?.docs ?? [];
          if (allDocs.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('notifications.none'.tr()),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _openBroadcastNotificationForm,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Add'),
                ),
              ],
            );
          }
          final docs = _previewDocs(allDocs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitleBar(
                title: 'admin.sections.notifications_panel'.tr(),
                actions: [
                  ElevatedButton.icon(
                    onPressed: _openBroadcastNotificationForm,
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Add'),
                  ),
                  const SizedBox(width: 8),
                ],
                onShowAll: () => _openAdminRecordsView(
                  title: 'admin.sections.notifications_panel'.tr(),
                  docs: allDocs,
                  searchHint: 'Search notifications',
                  searchTextBuilder: (doc) {
                    final d = doc.data();
                    return '${d['title'] ?? ''} ${d['body'] ?? ''} ${d['type'] ?? ''}';
                  },
                  itemBuilder: _buildNotificationAdminTile,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map(_buildNotificationAdminTile),
            ],
          );
        },
      ),
    );
  }
}

class _AdminRecordsScreen extends StatefulWidget {
  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String searchHint;
  final String Function(QueryDocumentSnapshot<Map<String, dynamic>>) searchTextBuilder;
  final Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;

  const _AdminRecordsScreen({
    required this.title,
    required this.docs,
    required this.searchHint,
    required this.searchTextBuilder,
    required this.itemBuilder,
  });

  @override
  State<_AdminRecordsScreen> createState() => _AdminRecordsScreenState();
}

class _AdminRecordsScreenState extends State<_AdminRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final docs = widget.docs.where((doc) {
      if (query.isEmpty) {
        return true;
      }
      return widget.searchTextBuilder(doc).toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(
        leading: const AdaptiveAppBarLeading(),
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                context.locale.languageCode == 'ar'
                    ? 'لا توجد نتائج مطابقة.'
                    : 'No matching results.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...docs.map(widget.itemBuilder),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Stream<int> stream;

  const _MetricTile({
    required this.title,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.panel(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 6),
            StreamBuilder<int>(
              stream: stream,
              builder: (context, snap) {
                final value = snap.hasError ? '!' : '${snap.data ?? 0}';
                return Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureAmountMetricTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Future<_AdvancedStats> future;
  final double Function(_AdvancedStats stats) selector;

  const _FutureAmountMetricTile({
    required this.title,
    required this.icon,
    required this.future,
    required this.selector,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.panel(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 6),
            FutureBuilder<_AdvancedStats>(
              future: future,
              builder: (context, snap) {
                final value = snap.data == null
                    ? '...'
                    : '${selector(snap.data!).toStringAsFixed(2)} ${'common.currency_egp'.tr()}';
                return Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerDocumentButton extends StatelessWidget {
  final String label;
  final String url;
  final bool isImage;
  final Future<void> Function(String url) onOpen;

  const _SellerDocumentButton({
    required this.label,
    required this.url,
    required this.isImage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    return OutlinedButton.icon(
      onPressed: hasUrl ? () => onOpen(url) : null,
      icon: isImage
          ? _RemoteThumbnail(url: hasUrl ? url : null, size: 28)
          : const Icon(Icons.attach_file_outlined),
      label: Text(label),
    );
  }
}

class _RemoteThumbnail extends StatelessWidget {
  final String? url;
  final double size;

  const _RemoteThumbnail({
    required this.url,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final value = (url ?? '').trim();
    if (value.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.panelSoft(context),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: RemoteImage(
        imageUrl: value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: Container(
          width: size,
          height: size,
          color: AppTheme.panelSoft(context),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _AdvancedStats {
  final double totalRevenue;
  final double platformRevenue;
  final int activeOrders;
  final List<MapEntry<String, double>> topSellers;
  final List<MapEntry<String, double>> topCategories;

  const _AdvancedStats({
    required this.totalRevenue,
    required this.platformRevenue,
    required this.activeOrders,
    required this.topSellers,
    required this.topCategories,
  });
}
