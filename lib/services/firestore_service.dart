import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/category.dart';
import '../models/product.dart';
import '../models/order.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// create or update user is handled by AuthService

  /// Categories
  Stream<List<Category>> getCategories() {
    return _db
        .collection('categories')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Category.fromDoc(d)).toList());
  }

  Stream<Map<String, dynamic>?> getFeaturedOffer() {
    return _db
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        return null;
      }
      return _normalizeOfferData(snap.docs.first);
    });
  }

  Stream<List<Map<String, dynamic>>> getActiveOffers({int limit = 10}) {
    return _db
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(_normalizeOfferData)
              .toList(),
        );
  }

  Stream<List<Product>> getBestSellerProducts({int limit = 8}) {
    return _db
        .collection('products')
        .where('isApproved', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .orderBy('salesCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromDoc(d)).toList());
  }

  /// Products with pagination & filters
  Stream<List<Product>> getProducts({
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String? sellerId,
    String? supplierId,
    bool onlyApproved = true,
    bool onlyActive = true,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _db.collection('products');
    if (onlyApproved) {
      query = query.where('isApproved', isEqualTo: true);
    }
    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }
    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }
    if (supplierId != null) {
      query = query.where('supplierId', isEqualTo: supplierId);
    }
    if (minPrice != null) {
      query = query.where('sellingPrice', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('sellingPrice', isLessThanOrEqualTo: maxPrice);
    }
    query = query.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => Product.fromDoc(d)).toList(),
        );
  }

  Future<ProductPage> fetchProductsPage({
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool onlyDiscounted = false,
    bool onlyApproved = true,
    bool onlyActive = true,
    bool bestSellers = false,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('products');
    if (onlyApproved) {
      query = query.where('isApproved', isEqualTo: true);
    }
    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }
    if (minPrice != null) {
      query = query.where('sellingPrice', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('sellingPrice', isLessThanOrEqualTo: maxPrice);
    }
    if (minRating != null && minRating > 0) {
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }
    if (onlyDiscounted) {
      query = query.where('hasDiscount', isEqualTo: true);
    }

    if (bestSellers) {
      query = query.orderBy('salesCount', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    return ProductPage(
      items: docs.map(Product.fromDoc).toList(),
      lastDocument: docs.isNotEmpty ? docs.last : null,
      hasMore: docs.length == limit,
    );
  }

  /// Create order
  Future<void> createOrder(Order order) {
    final base = order.toMap();
    final total = ((base['totalAmount'] ?? 0) as num).toDouble();
    final platformFee = double.parse((total * 0.02).toStringAsFixed(2));
    final sellerRevenue = double.parse((total - platformFee).toStringAsFixed(2));
    return _db.collection('orders').add({
      ...base,
      'customerName': ((base['address'] ?? const <String, dynamic>{}) as Map)['fullName'],
      'platform_fee': platformFee,
      'seller_revenue': sellerRevenue,
      'commission': platformFee,
      'payment_status': (base['paymentStatus'] ?? 'pending'),
    });
  }

  /// Additional service methods will be added as features expand.

  Map<String, dynamic> _normalizeOfferData(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawImages = data['images'];
    final images = rawImages is List
        ? rawImages
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList()
        : const <String>[];
    final imageUrl = (data['imageUrl'] ??
            data['bannerUrl'] ??
            data['coverImage'] ??
            (images.isNotEmpty ? images.first : ''))
        .toString()
        .trim();

    return <String, dynamic>{
      'id': doc.id,
      ...data,
      'images': images,
      'imageUrl': imageUrl,
    };
  }
}

class ProductPage {
  final List<Product> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  ProductPage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}
