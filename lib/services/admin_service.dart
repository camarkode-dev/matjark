import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const List<({String id, String nameAr, String nameEn})>
      _defaultCategories = [
    (id: 'fashion_women', nameAr: 'أزياء نسائية', nameEn: 'Women Fashion'),
    (id: 'fashion_men', nameAr: 'أزياء رجالية', nameEn: 'Men Fashion'),
    (id: 'shoes', nameAr: 'أحذية', nameEn: 'Shoes'),
    (id: 'bags', nameAr: 'حقائب', nameEn: 'Bags'),
    (id: 'watches', nameAr: 'ساعات', nameEn: 'Watches'),
    (id: 'beauty', nameAr: 'الجمال والعناية', nameEn: 'Beauty'),
    (id: 'electronics', nameAr: 'إلكترونيات', nameEn: 'Electronics'),
    (id: 'mobiles', nameAr: 'هواتف وإكسسوارات', nameEn: 'Mobiles'),
    (id: 'computers', nameAr: 'كمبيوتر ولابتوب', nameEn: 'Computers'),
    (id: 'gaming', nameAr: 'ألعاب إلكترونية', nameEn: 'Gaming'),
    (id: 'home_kitchen', nameAr: 'المنزل والمطبخ', nameEn: 'Home & Kitchen'),
    (id: 'furniture', nameAr: 'أثاث', nameEn: 'Furniture'),
    (id: 'appliances', nameAr: 'أجهزة منزلية', nameEn: 'Appliances'),
    (id: 'groceries', nameAr: 'سوبرماركت', nameEn: 'Groceries'),
    (id: 'baby', nameAr: 'الأطفال والرضع', nameEn: 'Baby'),
    (id: 'toys', nameAr: 'ألعاب', nameEn: 'Toys'),
    (id: 'sports', nameAr: 'رياضة ولياقة', nameEn: 'Sports'),
    (id: 'books', nameAr: 'كتب وقرطاسية', nameEn: 'Books'),
    (id: 'automotive', nameAr: 'السيارات', nameEn: 'Automotive'),
    (id: 'pets', nameAr: 'مستلزمات الحيوانات', nameEn: 'Pet Supplies'),
    (id: 'health', nameAr: 'الصحة', nameEn: 'Health'),
  ];

  bool isProtectedAdminEmail(String? email) {
    final normalized = (email ?? '').trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized == AppStrings.adminEmail.toLowerCase();
  }

  Future<void> approveSellerRequest({
    required String requestId,
    required String uid,
    String? reviewerUid,
  }) async {
    final batch = _db.batch();
    batch.set(
        _db.collection('seller_requests').doc(requestId),
        {
          'status': 'approved',
          'reviewedBy': reviewerUid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _db.collection('users').doc(uid),
        {
          'role': 'seller',
          'status': 'approved',
          'isApproved': true,
          'sellerApproved': true,
          'sellerRequestStatus': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> rejectSellerRequest({
    required String requestId,
    required String uid,
    String? reviewerUid,
  }) async {
    final batch = _db.batch();
    batch.set(
        _db.collection('seller_requests').doc(requestId),
        {
          'status': 'rejected',
          'reviewedBy': reviewerUid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    batch.set(
        _db.collection('users').doc(uid),
        {
          'sellerApproved': false,
          'sellerRequestStatus': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteSellerRequest({
    required String requestId,
    required String uid,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.collection('seller_requests').doc(requestId));
    batch.set(
        _db.collection('users').doc(uid),
        {
          'role': 'customer',
          'status': 'approved',
          'isApproved': true,
          'sellerApproved': false,
          'sellerRequestStatus': 'none',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> suspendUser({
    required String uid,
    String? email,
  }) async {
    _ensureMutableAccount(email);
    await _db.collection('users').doc(uid).set({
      'status': 'suspended',
      'isApproved': false,
      'sellerApproved': false,
      'sellerRequestStatus': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final products = await _db
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .get();
    await _applyChunkedWrites(products.docs, (batch, doc) {
      batch.set(
          doc.reference,
          {
            'isApproved': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> reactivateUser({
    required String uid,
  }) async {
    final userSnapshot = await _db.collection('users').doc(uid).get();
    final data = userSnapshot.data() ?? const <String, dynamic>{};
    final isSeller = (data['role'] ?? '').toString() == 'seller';
    await _db.collection('users').doc(uid).set({
      'status': 'approved',
      'isApproved': true,
      if (isSeller) 'sellerApproved': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSellerAccount({
    required String uid,
    String? email,
  }) async {
    _ensureMutableAccount(email);
    await _deleteQuery(
      _db.collection('seller_requests').where('uid', isEqualTo: uid),
    );
    await _deleteQuery(
      _db.collection('products').where('sellerId', isEqualTo: uid),
    );
    await _deleteQuery(
      _db.collection('notifications').where('userId', isEqualTo: uid),
    );
    await _db.collection('users').doc(uid).delete();
  }

  Future<void> upsertProduct({
    String? productId,
    required Map<String, dynamic> data,
  }) async {
    final doc = productId == null
        ? _db.collection('products').doc()
        : _db.collection('products').doc(productId);
    final payload = _normalizeProductPayload(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (productId == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
      payload['rating'] ??= 0;
      payload['salesCount'] ??= 0;
    }
    await doc.set(payload, SetOptions(merge: true));
  }

  Future<void> upsertCategory({
    String? categoryId,
    required String nameAr,
    required String nameEn,
    String? imageUrl,
  }) async {
    final doc = categoryId == null
        ? _db.collection('categories').doc()
        : _db.collection('categories').doc(categoryId);
    final payload = <String, dynamic>{
      'nameAr': nameAr,
      'nameEn': nameEn,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (categoryId == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await doc.set(payload, SetOptions(merge: true));
  }

  Future<void> deleteCategory(String categoryId) async {
    await _db.collection('categories').doc(categoryId).delete();
    final products = await _db
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .get();
    await _applyChunkedWrites(products.docs, (batch, doc) {
      batch.set(
          doc.reference,
          {
            'categoryId': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<int> seedDefaultCategories() async {
    var written = 0;
    for (var i = 0; i < _defaultCategories.length; i += 400) {
      final batch = _db.batch();
      final chunk = _defaultCategories.skip(i).take(400);
      for (final category in chunk) {
        final doc = _db.collection('categories').doc(category.id);
        batch.set(
          doc,
          {
            'nameAr': category.nameAr,
            'nameEn': category.nameEn,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        written++;
      }
      await batch.commit();
    }
    return written;
  }

  Map<String, dynamic> _normalizeProductPayload(Map<String, dynamic> data) {
    final titleAr = (data['titleAr'] ?? '').toString().trim();
    final titleEn = (data['titleEn'] ?? '').toString().trim();
    final sellerId =
        (data['sellerId'] ?? data['vendorId'] ?? '').toString().trim();
    final sellingPrice = ((data['sellingPrice'] ?? 0) as num).toDouble();
    final costPrice = ((data['costPrice'] ?? sellingPrice) as num).toDouble();
    final rawImages = data['images'];
    final images = rawImages is List
        ? rawImages
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList()
        : <String>[];
    final imageUrl = images.isNotEmpty
        ? images.first
        : (data['imageUrl'] ?? '').toString().trim();
    final normalizedText = '$titleAr $titleEn'
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return <String, dynamic>{
      ...data,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'name': titleEn.isNotEmpty ? titleEn : titleAr,
      'nameLower': normalizedText,
      'searchKeywords': normalizedText.isEmpty
          ? <String>[]
          : normalizedText
              .split(' ')
              .where((part) => part.isNotEmpty)
              .toSet()
              .toList(),
      'sellingPrice': sellingPrice,
      'price': sellingPrice,
      'costPrice': costPrice,
      'images': images,
      'imageUrl': imageUrl,
      'sellerId': sellerId,
      'vendorId': sellerId,
      'isActive': data['isActive'] != false,
      'stockStatus': ((data['stock'] ?? 0) as num).toInt() > 0
          ? 'in_stock'
          : 'out_of_stock',
    };
  }

  void _ensureMutableAccount(String? email) {
    if (isProtectedAdminEmail(email)) {
      throw StateError('Protected admin account cannot be modified.');
    }
  }

  Future<void> _deleteQuery(
    Query<Map<String, dynamic>> query, {
    int pageSize = 100,
  }) async {
    while (true) {
      final snapshot = await query.limit(pageSize).get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      await _applyChunkedWrites(snapshot.docs, (batch, doc) {
        batch.delete(doc.reference);
      });
      if (snapshot.docs.length < pageSize) {
        break;
      }
    }
  }

  Future<void> _applyChunkedWrites(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    void Function(
      WriteBatch batch,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) apply,
  ) async {
    for (var i = 0; i < docs.length; i += 400) {
      final chunk = docs.skip(i).take(400);
      final batch = _db.batch();
      for (final doc in chunk) {
        apply(batch, doc);
      }
      await batch.commit();
    }
  }

  Future<int> createBroadcastNotification({
    required String title,
    required String body,
    String type = 'admin_broadcast',
  }) async {
    final broadcastRef = _db.collection('admin_broadcasts').doc();
    final allUsers = await _db.collection('users').get();
    final recipients = allUsers.docs.where(_isNotificationRecipient).toList();
    final timestamp = FieldValue.serverTimestamp();
    await broadcastRef.set({
      'type': type,
      'title': title,
      'body': body,
      'recipientRoles': const ['customer', 'seller'],
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    if (recipients.isEmpty) {
      return 0;
    }

    for (var i = 0; i < recipients.length; i += 400) {
      final chunk = recipients.skip(i).take(400);
      final batch = _db.batch();
      for (final userDoc in chunk) {
        final notificationRef = _db.collection('notifications').doc();
        batch.set(notificationRef, {
          'broadcastId': broadcastRef.id,
          'userId': userDoc.id,
          'type': type,
          'title': title,
          'body': body,
          'isRead': false,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
      }
      await batch.commit();
    }
    return recipients.length;
  }

  bool _isNotificationRecipient(
    QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
  ) {
    final data = userDoc.data();
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final role = (data['role'] ?? 'customer').toString().trim().toLowerCase();
    final status = (data['status'] ?? 'approved').toString().trim().toLowerCase();

    if (userDoc.id.isEmpty) {
      return false;
    }
    if (status == 'suspended') {
      return false;
    }
    if (role == 'admin') {
      return false;
    }
    if (email == AppStrings.adminEmail.toLowerCase()) {
      return false;
    }
    return true;
  }

  Future<void> updateBroadcastNotification({
    required String broadcastId,
    required String title,
    required String body,
  }) async {
    await _db.collection('admin_broadcasts').doc(broadcastId).set({
      'title': title,
      'body': body,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final notifications = await _db
        .collection('notifications')
        .where('broadcastId', isEqualTo: broadcastId)
        .get();
    await _applyChunkedWrites(notifications.docs, (batch, doc) {
      batch.set(
          doc.reference,
          {
            'title': title,
            'body': body,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> deleteBroadcastNotification(String broadcastId) async {
    await _db.collection('admin_broadcasts').doc(broadcastId).delete();
    await _deleteQuery(
      _db
          .collection('notifications')
          .where('broadcastId', isEqualTo: broadcastId),
    );
  }
}
