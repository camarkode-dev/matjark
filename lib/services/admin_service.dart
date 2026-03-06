import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    batch.set(_db.collection('seller_requests').doc(requestId), {
      'status': 'approved',
      'reviewedBy': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(uid), {
      'role': 'seller',
      'status': 'approved',
      'isApproved': true,
      'sellerRequestStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> rejectSellerRequest({
    required String requestId,
    required String uid,
    String? reviewerUid,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection('seller_requests').doc(requestId), {
      'status': 'rejected',
      'reviewedBy': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(uid), {
      'sellerRequestStatus': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteSellerRequest({
    required String requestId,
    required String uid,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.collection('seller_requests').doc(requestId));
    batch.set(_db.collection('users').doc(uid), {
      'role': 'customer',
      'status': 'approved',
      'isApproved': true,
      'sellerRequestStatus': 'none',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      'sellerRequestStatus': 'suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final products = await _db
        .collection('products')
        .where('sellerId', isEqualTo: uid)
        .get();
    await _applyChunkedWrites(products.docs, (batch, doc) {
      batch.set(doc.reference, {
        'isApproved': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> reactivateUser({
    required String uid,
  }) async {
    await _db.collection('users').doc(uid).set({
      'status': 'approved',
      'isApproved': true,
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
    final payload = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
      batch.set(doc.reference, {
        'categoryId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
    final recipients = await _db
        .collection('users')
        .where('role', whereIn: const ['customer', 'seller'])
        .get();
    final timestamp = FieldValue.serverTimestamp();
    await broadcastRef.set({
      'type': type,
      'title': title,
      'body': body,
      'recipientRoles': const ['customer', 'seller'],
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    if (recipients.docs.isEmpty) {
      return 0;
    }

    for (var i = 0; i < recipients.docs.length; i += 400) {
      final chunk = recipients.docs.skip(i).take(400);
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
    return recipients.docs.length;
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
      batch.set(doc.reference, {
        'title': title,
        'body': body,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> deleteBroadcastNotification(String broadcastId) async {
    await _db.collection('admin_broadcasts').doc(broadcastId).delete();
    await _deleteQuery(
      _db.collection('notifications').where('broadcastId', isEqualTo: broadcastId),
    );
  }
}
