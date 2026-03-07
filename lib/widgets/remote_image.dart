import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RemoteImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;
  final Widget? placeholder;

  const RemoteImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        const Center(
          child: Icon(Icons.broken_image_outlined),
        );
    final loading = placeholder ??
        const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

    final image = kIsWeb
        ? Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, __, ___) => fallback,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }
              return loading;
            },
          )
        : CachedNetworkImage(
            imageUrl: imageUrl,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, __) => loading,
            errorWidget: (_, __, ___) => fallback,
          );

    if (borderRadius == null) {
      return image;
    }
    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }
}
