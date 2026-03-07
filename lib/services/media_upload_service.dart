import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProductImage({
    required String ownerId,
    String? productId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      folder: 'product_images/$ownerId/${productId ?? 'drafts'}',
      ownerId: ownerId,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadCategoryImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      folder: 'category_images',
      ownerId: 'admin',
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadOfferImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      folder: 'offer_images',
      ownerId: 'admin',
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadPaymentReceipt({
    required String ownerId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      folder: 'payment_receipts/$ownerId/drafts',
      ownerId: ownerId,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadReturnEvidence({
    required String ownerId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      folder: 'return_request_images/$ownerId/drafts',
      ownerId: ownerId,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> _uploadImage({
    required String folder,
    required String ownerId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path =
        '$folder/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    final ref = _storage.ref(path);
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _resolveContentType(fileName),
        customMetadata: {'ownerUid': ownerId},
      ),
    );
    return snapshot.ref.getDownloadURL();
  }

  String _resolveContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}
