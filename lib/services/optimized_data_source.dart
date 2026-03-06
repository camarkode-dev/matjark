import 'package:flutter/foundation.dart';
import '../models/category.dart' as models;
import '../models/product.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';

/// Optimized data source combining Firestore with intelligent caching
class OptimizedDataSource {
  final FirestoreService _firestoreService = FirestoreService();
  final CacheService _cacheService = CacheService();
  
  /// Get categories from cache or Firestore
  Future<List<models.Category>> getCategories({bool forceRefresh = false}) async {
    const key = 'categories_all';
    
    // Return cached if available and not forced refresh
    if (!forceRefresh) {
      final cached = _cacheService.get<List<models.Category>>(key);
      if (cached != null) {
        debugPrint('✓ Categories from cache');
        return cached;
      }
    }
    
    try {
      debugPrint('⏳ Loading categories from Firestore...');
      final categories = await _firestoreService
          .getCategories()
          .first; // Get first emission from stream
      
      // Cache for 12 hours
      _cacheService.set(key, categories, ttl: const Duration(hours: 12));
      debugPrint('✓ Categories cached (${categories.length} items)');
      
      return categories;
    } catch (e) {
      debugPrint('✗ Error loading categories: $e');
      rethrow;
    }
  }
  
  /// Get products with intelligent pagination and caching
  Future<List<Product>> getProducts({
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    int limit = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _buildCacheKey(
      'products',
      categoryId,
      minPrice,
      maxPrice,
    );
    
    if (!forceRefresh) {
      final cached = _cacheService.get<List<Product>>(cacheKey);
      if (cached != null) {
        debugPrint('✓ Products from cache (${cached.length} items)');
        return cached;
      }
    }
    
    try {
      debugPrint('⏳ Loading products from Firestore...');
      final products = await _firestoreService
          .getProducts(
            categoryId: categoryId,
            minPrice: minPrice,
            maxPrice: maxPrice,
            limit: limit,
          )
          .first;
      
      // Cache for 6 hours
      _cacheService.set(cacheKey, products, ttl: const Duration(hours: 6));
      debugPrint('✓ Products cached (${products.length} items)');
      
      return products;
    } catch (e) {
      debugPrint('✗ Error loading products: $e');
      rethrow;
    }
  }
  
  /// Get single product detail with caching (Not implemented - requires FirestoreService.getProduct)
  /// To use: Implement getProduct(productId) -> Stream<Product?> in FirestoreService
  // Future<Product?> getProductDetail(String productId) async {
  //   final cacheKey = 'product_$productId';
  //   
  //   // Try cache first
  //   final cached = _cacheService.get<Product>(cacheKey);
  //   if (cached != null) {
  //     debugPrint('✓ Product detail from cache');
  //     return cached;
  //   }
  //   
  //   try {
  //     debugPrint('⏳ Loading product detail from Firestore...');
  //     final product = await _firestoreService
  //         .getProduct(productId)
  //         .first;
  //     
  //     if (product != null) {
  //       _cacheService.set(cacheKey, product, ttl: const Duration(hours: 12));
  //       debugPrint('✓ Product detail cached');
  //     }
  //     
  //     return product;
  //   } catch (e) {
  //     debugPrint('✗ Error loading product detail: $e');
  //     return null;
  //   }
  // }
  
  /// Clear cache for specific types
  void clearCache({
    required String type, // 'categories', 'products', 'all'
    String? categoryId,
  }) {
    if (type == 'categories' || type == 'all') {
      _cacheService.remove('categories_all');
    }
    if (type == 'products' || type == 'all') {
      if (categoryId != null) {
        _cacheService.remove('products_$categoryId');
      } else {
        // Clear all product caches (expensive operation)
        _cacheService.clearAll();
      }
    }
  }
  
  /// Build cache key from multiple parameters
  String _buildCacheKey(
    String prefix,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
  ) {
    return '$prefix:c=$categoryId:min=$minPrice:max=$maxPrice';
  }
  
  /// Print cache statistics
  void printStats() {
    _cacheService.printStats();
  }
}
