import 'package:flutter/material.dart';
import '../services/optimized_data_source.dart';

/// Precaching manager for app initialization
/// Ensures critical data is loaded before user sees the app
class PrecacheManager {
  static final PrecacheManager _instance = PrecacheManager._internal();
  static bool _isInitialized = false;
  
  factory PrecacheManager() => _instance;
  
  PrecacheManager._internal();
  
  final OptimizedDataSource _dataSource = OptimizedDataSource();
  
  /// Initialize precaching on app launch
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🔄 Starting precache initialization...');
      
      // Load categories first (required by most screens)
      await _instance._dataSource.getCategories();
      
      // Precache top categories' products
      final categories = await _instance._dataSource.getCategories();
      for (var i = 0; i < (categories.length > 3 ? 3 : categories.length); i++) {
        await _instance._dataSource.getProducts(
          categoryId: categories[i].id,
          limit: 10,
        );
      }
      
      debugPrint('✅ Precache initialization completed');
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ Precache initialization failed: $e');
      // App continues anyway, data will load on demand
    }
  }
  
  /// Precache images for a list of URLs
  static Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (e) {
        debugPrint('Failed to precache image: $e');
      }
    }
  }
  
  /// Clear all caches (useful after logout)
  static void clearCache() {
    _instance._dataSource.clearCache(type: 'all');
    _isInitialized = false;
  }
  
  /// Print precache statistics
  static void printStats() {
    _instance._dataSource.printStats();
  }
}
