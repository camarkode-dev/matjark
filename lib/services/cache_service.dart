import 'package:flutter/foundation.dart';

/// Advanced caching service for products, categories, and orders
/// Uses in-memory caching with TTL (time-to-live) for optimal performance
class CacheService {
  static final CacheService _instance = CacheService._internal();
  
  factory CacheService() {
    return _instance;
  }
  
  CacheService._internal();
  
  // Cache storage with TTL
  final Map<String, CacheEntry> _cache = {};
  
  // Cache statistics for monitoring
  int _hits = 0;
  int _misses = 0;
  
  /// Get cache hit rate percentage
  double get cacheHitRate {
    int total = _hits + _misses;
    if (total == 0) return 0;
    return (_hits / total) * 100;
  }
  
  /// Get cached value if not expired
  T? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) {
      _misses++;
      return null;
    }
    
    // Check if expired
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      _misses++;
      return null;
    }
    
    _hits++;
    return entry.value as T?;
  }
  
  /// Set cache value with TTL
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? const Duration(hours: 6)),
    );
  }
  
  /// Clear specific cache entry
  void remove(String key) {
    _cache.remove(key);
  }
  
  /// Clear all expired entries
  void clearExpired() {
    _cache.removeWhere((_, entry) => DateTime.now().isAfter(entry.expiresAt));
  }
  
  /// Clear entire cache
  void clearAll() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }
  
  /// Print cache statistics
  void printStats() {
    debugPrint('''
    ╔═══════════════════════════════════╗
    ║     CACHE STATISTICS              ║
    ╠═══════════════════════════════════╣
    ║ Entries:        ${_cache.length.toString().padRight(19)}║
    ║ Hits:           ${_hits.toString().padRight(19)}║
    ║ Misses:         ${_misses.toString().padRight(19)}║
    ║ Hit Rate:       ${cacheHitRate.toStringAsFixed(2)}%${' '.padRight(14)}║
    ╚═══════════════════════════════════╝
    ''');
  }
}

/// Cache entry with expiration
class CacheEntry {
  final dynamic value;
  final DateTime expiresAt;
  
  CacheEntry({
    required this.value,
    required this.expiresAt,
  });
}
