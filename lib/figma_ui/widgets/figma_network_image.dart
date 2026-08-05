import 'package:flutter/material.dart';

/// Mirrors `ImageWithFallback`: network image with a neutral placeholder on error.
class FigmaNetworkImage extends StatelessWidget {
  const FigmaNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = url.startsWith('assets/')
        ? Image.asset(
            url,
            fit: fit,
            errorBuilder: (_, __, ___) => _placeholder(),
          )
        : Image.network(
            url,
            fit: fit,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => _placeholder(),
          );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
    );
  }
}
