import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Image optimization utilities for web and mobile
/// Reduces memory usage and improves rendering performance
class ImageOptimizer {
  /// Get optimized image provider with caching
  static ImageProvider getOptimizedImage(
    String imageUrl, {
    required int width,
    required int height,
    BoxFit fit = BoxFit.cover,
  }) {
    try {
      return CachedNetworkImageProvider(
        imageUrl,
        cacheKey: '$imageUrl?w=$width&h=$height',
        maxHeight: height,
        maxWidth: width,
      );
    } catch (e) {
      return const AssetImage('assets/placeholder.png');
    }
  }
  
  /// Build cached network image widget
  static Widget cachedNetworkImage(
    String imageUrl, {
    double width = double.infinity,
    double height = 200,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        cacheKey: '$imageUrl?w=${width.toInt()}&h=${height.toInt()}',
        // Progressive loading
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            placeholder ??
            Container(
              color: Colors.grey[300],
              child: Center(
                child: CircularProgressIndicator(
                  value: downloadProgress.progress,
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Container(
              color: Colors.grey[400],
              child: const Icon(Icons.image_not_supported),
            ),
        // Memory cache: 50MB, Disk cache: 100MB
        maxHeightDiskCache: height.toInt(),
        maxWidthDiskCache: width.toInt(),
      ),
    );
  }
  
  /// Precache images for better performance
  static Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (String url in imageUrls) {
      try {
        await precacheImage(NetworkImage(url), context);
      } catch (e) {
        debugPrint('Failed to precache image: $url - $e');
      }
    }
  }
}
