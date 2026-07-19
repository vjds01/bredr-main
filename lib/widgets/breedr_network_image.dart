import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BreedrNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;
  final Color backgroundColor;
  final double loaderSize;

  const BreedrNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
    this.backgroundColor = const Color(0xFFFFEEF3),
    this.loaderSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    final child = trimmedUrl.isEmpty
        ? _fallback()
        : Image.network(
            trimmedUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _LoadingImageBox(
                width: width,
                height: height,
                backgroundColor: backgroundColor,
                loaderSize: loaderSize,
                progress: progress,
              );
            },
            errorBuilder: (_, _, _) => _fallback(),
          );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _fallback() {
    return SizedBox(
      width: width,
      height: height,
      child: fallback ??
          ColoredBox(
            color: backgroundColor,
            child: const Center(
              child: Icon(Icons.pets, color: AppColors.primary),
            ),
          ),
    );
  }
}

class _LoadingImageBox extends StatelessWidget {
  final double? width;
  final double? height;
  final Color backgroundColor;
  final double loaderSize;
  final ImageChunkEvent progress;

  const _LoadingImageBox({
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.loaderSize,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final expectedBytes = progress.expectedTotalBytes;
    final value = expectedBytes == null || expectedBytes == 0
        ? null
        : progress.cumulativeBytesLoaded / expectedBytes;

    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: backgroundColor,
        child: Center(
          child: SizedBox(
            width: loaderSize,
            height: loaderSize,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
