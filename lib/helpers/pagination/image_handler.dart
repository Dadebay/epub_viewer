import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html/dom.dart' as dom;

/// Handles image processing for EPUB content
class ImageHandler {
  final EpubBook? epubBook;
  final double maxDisplayHeight;

  ImageHandler({
    required this.epubBook,
    required this.maxDisplayHeight,
  });

  Future<InlineSpan> handleImageNode(dom.Element node, double maxWidth) async {
    String? src = node.attributes['src'];

    if (src == null || epubBook == null) {
      return const TextSpan(text: "");
    }

    final imageContent = _findImage(src);

    if (imageContent == null) {
      return _createNotFoundWidget(src);
    }

    try {
      final bytes = imageContent.Content as List<int>;
      final uint8list = Uint8List.fromList(bytes);
      final codec = await ui.instantiateImageCodec(uint8list);
      final frameInfo = await codec.getNextFrame();
      final imageWidth = frameInfo.image.width.toDouble();
      final imageHeight = frameInfo.image.height.toDouble();
      double availableWidth = maxWidth * 0.95;
      double displayWidth = imageWidth;
      double displayHeight = imageHeight;

      if (displayWidth > availableWidth) {
        displayWidth = availableWidth;
        displayHeight = (displayWidth / imageWidth) * imageHeight;
      }

      if (displayHeight > maxDisplayHeight) {
        displayHeight = maxDisplayHeight;
        displayWidth = (displayHeight / imageHeight) * imageWidth;
      }

      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                uint8list,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImageError(displayWidth);
                },
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return _createErrorWidget(src, maxWidth);
    }
  }

  EpubByteContentFile? _findImage(String src) {
    if (epubBook?.Content?.Images == null) {
      return null;
    }

    final images = epubBook!.Content!.Images!;
    if (images.containsKey(src)) {
      return images[src];
    }

    try {
      final decoded = Uri.decodeFull(src);
      if (images.containsKey(decoded)) {
        return images[decoded];
      }
    } catch (_) {}

    final noLeading = src.startsWith('/') ? src.substring(1) : src;
    if (images.containsKey(noLeading)) {
      return images[noLeading];
    }

    String cleanSrc = src.replaceAll('../', '').replaceAll('./', '').replaceAll('\\', '/').trim();

    if (images.containsKey(cleanSrc)) {
      return images[cleanSrc];
    }

    final filename = cleanSrc.split('/').last;

    for (var key in images.keys) {
      final cleanKey = key.replaceAll('\\', '/');

      if (cleanKey == cleanSrc || cleanKey.endsWith(filename) || cleanKey.toLowerCase().endsWith(filename.toLowerCase())) {
        return images[key];
      }
    }

    final lowerSrc = cleanSrc.toLowerCase();
    for (var key in images.keys) {
      if (key.toLowerCase() == lowerSrc) {
        return images[key];
      }
    }

    return null;
  }

  Widget _buildImageError(double width) {
    return Container(
      width: width,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
          const SizedBox(height: 8),
          Text(
            'Image error',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  InlineSpan _createErrorWidget(String src, double maxWidth) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        width: maxWidth * 0.9,
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          border: Border.all(color: Colors.orange[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 24, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    src.split('/').last,
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InlineSpan _createNotFoundWidget(String src) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Image not found: ${src.split('/').last}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
