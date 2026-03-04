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

  /// Products with pagination & filters
  Stream<List<Product>> getProducts({
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String? sellerId,
    String? supplierId,
    bool onlyApproved = true,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    Query query = _db.collection('products');
    if (onlyApproved) query = query.where('isApproved', isEqualTo: true);
    if (categoryId != null) query = query.where('categoryId', isEqualTo: categoryId);
    if (sellerId != null) query = query.where('sellerId', isEqualTo: sellerId);
    if (supplierId != null) query = query.where('supplierId', isEqualTo: supplierId);
    if (minPrice != null) query = query.where('sellingPrice', isGreaterThanOrEqualTo: minPrice);
    if (maxPrice != null) query = query.where('sellingPrice', isLessThanOrEqualTo: maxPrice);
    query = query.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return query.snapshots().map((snap) => snap.docs.map((d) => Product.fromDoc(d)).toList());
  }

  /// Create order
  Future<void> createOrder(Order order) {
    return _db.collection('orders').add(order.toMap());
  }

  /// Additional service methods will be added as features expand.
}
