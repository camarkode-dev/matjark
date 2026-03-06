/// Performance optimization configurations for web and mobile
class PerformanceConfig {
  // Image optimization
  static const int imageMemoryCacheSize = 50 * 1024 * 1024; // 50MB
  static const int imageDiskCacheSize = 100 * 1024 * 1024; // 100MB
  
  // Network optimization
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration cacheExpiration = Duration(hours: 6);
  
  // Firestore optimization
  static const int productPageLimit = 15;
  static const int categoryPageLimit = 20;
  static const int orderPageLimit = 10;
  
  // Lazy loading
  static const int lazyLoadThreshold = 5; // Load next page when 5 items remain
  
  // Widget constraints for performance
  static const int maxItemsBeforeVirtualization = 100;
}
