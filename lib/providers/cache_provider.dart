import 'package:flutter/foundation.dart';
import '../models/category.dart' as models;
import '../models/product.dart';
import '../models/order.dart';
import '../services/cache_service.dart';

/// Caching provider for categories, products, and orders
/// Reduces Firestore queries and improves app responsiveness
class CacheProvider extends ChangeNotifier {
  final CacheService _cacheService = CacheService();
  
  // Cache keys
  static const String _categoriesKey = 'categories_all';
  static const String _productsPrefix = 'products_';
  static const String _productDetailPrefix = 'product_';
  static const String _orderPrefix = 'orders_';
  
  /// Cache categories
  void cacheCategories(List<models.Category> categories) {
    _cacheService.set(
      _categoriesKey,
      categories,
      ttl: const Duration(hours: 12),
    );
    notifyListeners();
  }
  
  /// Get cached categories
  List<models.Category>? getCachedCategories() {
    return _cacheService.get(_categoriesKey);
  }
  
  /// Cache products for a specific category
  void cacheProducts(String categoryId, List<Product> products) {
    _cacheService.set(
      '$_productsPrefix$categoryId',
      products,
      ttl: const Duration(hours: 6),
    );
  }
  
  /// Get cached products
  List<Product>? getCachedProducts(String categoryId) {
    return _cacheService.get('$_productsPrefix$categoryId');
  }
  
  /// Cache single product detail
  void cacheProductDetail(String productId, Product product) {
    _cacheService.set(
      '$_productDetailPrefix$productId',
      product,
      ttl: const Duration(hours: 12),
    );
  }
  
  /// Get cached product detail
  Product? getCachedProductDetail(String productId) {
    return _cacheService.get('$_productDetailPrefix$productId');
  }
  
  /// Cache user orders
  void cacheOrders(String userId, List<Order> orders) {
    _cacheService.set(
      '$_orderPrefix$userId',
      orders,
      ttl: const Duration(hours: 3),
    );
  }
  
  /// Get cached orders
  List<Order>? getCachedOrders(String userId) {
    return _cacheService.get('$_orderPrefix$userId');
  }
  
  /// Clear category cache
  void clearCategoryCache() {
    _cacheService.remove(_categoriesKey);
    notifyListeners();
  }
  
  /// Clear product cache for specific category
  void clearProductCache(String categoryId) {
    _cacheService.remove('$_productsPrefix$categoryId');
  }
  
  /// Clear all caches
  void clearAll() {
    _cacheService.clearAll();
    notifyListeners();
  }
  
  /// Print cache statistics
  void printCacheStats() {
    _cacheService.printStats();
  }
}
