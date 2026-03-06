import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_model.dart';

class SellerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadSellerDocument({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        'seller_documents/$uid/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    final ref = _storage.ref(path);
    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(
        contentType: _resolveContentType(fileName),
        customMetadata: {'ownerUid': uid},
      ),
    );

    try {
      final snapshot = await uploadTask;
      return snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' || e.code == 'unknown') {
        throw Exception(
          'Storage upload failed. Check Firebase Storage rules and CORS configuration.',
        );
      }
      rethrow;
    }
  }

  Future<void> submitSellerRequest({
    required AppUser user,
    required String merchantName,
    required String storeName,
    required String phoneNumber,
    required String nationalIdImage,
    String? commercialRegisterImage,
    String? taxCardImage,
  }) async {
    final requestRef = _db.collection('seller_requests').doc();
    await requestRef.set({
      'requestId': requestRef.id,
      'uid': user.uid,
      'email': user.email,
      'merchant_name': merchantName,
      'store_name': storeName,
      'phone_number': phoneNumber,
      'national_id_image': nationalIdImage,
      'commercial_register_image': commercialRegisterImage,
      'tax_card_image': taxCardImage,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(user.uid).set({
      'sellerRequestStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> latestRequestForUser(
    String uid,
  ) async {
    final query = await _db
        .collection('seller_requests')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  String _resolveContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }
}
