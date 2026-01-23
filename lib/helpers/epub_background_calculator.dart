import 'dart:developer' as dev;

import 'package:epubx/epubx.dart';

/// Helper class for background chapter calculations in EPUB reader
class EpubBackgroundCalculator {
  /// Calculate pages for all chapters in background based on content length
  /// This provides quick estimates without full pagination
  static Future<Map<int, int>> calculateAllChaptersInBackground({
    required List<EpubChapter> chapters,
    required double fontSize,
    required Function(int chapter, int pages) onChapterCalculated,
    required bool Function() shouldContinue,
    Map<int, int>? existingPageCounts, // Skip chapters that are already calculated
    bool verbose = true, // Control logging
  }) async {
    if (verbose) {
      dev.log('🔄 Starting background calculation for ALL chapters...');
      dev.log('📚 Total chapters to calculate: ${chapters.length}');
    }

    final Map<int, int> results = {};

    // Calculate each chapter based on content length
    for (int i = 0; i < chapters.length; i++) {
      if (!shouldContinue()) {
        if (verbose) dev.log('⚠️ Background calculation cancelled');
        break;
      }

      // Skip if already calculated with real pagination
      if (existingPageCounts != null && existingPageCounts.containsKey(i)) {
        if (verbose) dev.log('⏭️ Chapter $i already calculated (${existingPageCounts[i]} pages), skipping...');
        results[i] = existingPageCounts[i]!;
        continue;
      }

      try {
        // Get chapter content
        final content = chapters[i].HtmlContent ?? '';

        if (content.isEmpty) {
          if (verbose) dev.log('⚠️ Chapter $i has no content, skipping...');
          continue;
        }

        // Estimate pages based on content length and font size
        // Smaller font = more chars per page, larger font = fewer chars per page
        final fontSizeMultiplier = 14.0 / fontSize;
        final charsPerPage = (2000 * fontSizeMultiplier).round();
        // FIXED: Changed clamp(5, 100) to clamp(1, 100) - minimum 5 was causing wrong startPage calculations
        final estimatedPages = (content.length / charsPerPage).ceil().clamp(1, 100);

        // Only log in verbose mode
        // if (verbose) dev.log('✅ Chapter $i: $estimatedPages pages (estimated, fontSize: $fontSize)');

        results[i] = estimatedPages;
        onChapterCalculated(i, estimatedPages);

        // Small delay to avoid blocking UI
        await Future.delayed(Duration(milliseconds: 5));
      } catch (e) {
        if (verbose) dev.log('❌ Error calculating chapter $i: $e');
        // Use fallback estimate
        results[i] = 10;
        onChapterCalculated(i, 10);
      }
    }

    if (verbose) dev.log('✅ All chapters calculated! Total: ${results.values.fold(0, (a, b) => a + b)} pages');
    return results;
  }

  /// Estimate page count for a single chapter based on content length
  static int estimateChapterPages({
    required String content,
    required double fontSize,
  }) {
    if (content.isEmpty) return 1;

    final fontSizeMultiplier = 14.0 / fontSize;
    final charsPerPage = (2000 * fontSizeMultiplier).round();
    // FIXED: Changed clamp(5, 100) to clamp(1, 100) - minimum 5 was causing wrong startPage calculations
    final estimatedPages = (content.length / charsPerPage).ceil().clamp(1, 100);

    return estimatedPages;
  }
}
