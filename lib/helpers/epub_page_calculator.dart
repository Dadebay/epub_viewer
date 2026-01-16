/// Helper class for calculating page numbers and totals in EPUB reader
class EpubPageCalculator {
  /// Calculate accumulated pages before a specific chapter
  static int calculateAccumulatedPages(
    Map<int, int> chapterPageCounts,
    int beforeChapterIndex,
  ) {
    int accumulated = 0;
    for (int i = 0; i < beforeChapterIndex; i++) {
      final pageCount = chapterPageCounts[i] ?? 0;
      accumulated += pageCount;
    }
    return accumulated;
  }

  /// Calculate total pages up to and including current chapter
  static int calculateTotalPagesUpToCurrent(
    Map<int, int> chapterPageCounts,
    int currentChapterIndex,
  ) {
    int total = 0;
    for (int i = 0; i <= currentChapterIndex; i++) {
      total += chapterPageCounts[i] ?? 0;
    }
    return total;
  }

  /// Calculate current page in book (cumulative across all chapters)
  /// Returns 1-indexed page number
  static int calculateCurrentPageInBook({
    required Map<int, int> chapterPageCounts,
    required int currentChapterIndex,
    required int currentPageInChapter,
  }) {
    final accumulatedPages = calculateAccumulatedPages(
      chapterPageCounts,
      currentChapterIndex,
    );
    return accumulatedPages + currentPageInChapter + 1; // +1 for 1-indexed
  }

  /// Calculate display total pages (up to current chapter or full book if all calculated)
  static int calculateDisplayTotalPages({
    required Map<int, int> chapterPageCounts,
    required int currentChapterIndex,
    required bool allChaptersCalculated,
    required int totalPagesInBook,
    required int cachedKnownPagesTotal,
  }) {
    if (allChaptersCalculated) {
      return totalPagesInBook;
    }

    final totalUpToCurrent = calculateTotalPagesUpToCurrent(
      chapterPageCounts,
      currentChapterIndex,
    );

    if (totalUpToCurrent > 0) {
      return totalUpToCurrent;
    }

    return chapterPageCounts[currentChapterIndex] ?? (cachedKnownPagesTotal > 0 ? cachedKnownPagesTotal : totalPagesInBook);
  }

  /// Calculate which chapter and page a book page number corresponds to
  static Map<String, int>? calculateChapterAndPageFromBookPage(
    Map<int, int> chapterPageCounts,
    int targetPageInBook,
  ) {
    int accumulatedPages = 0;

    for (var entry in chapterPageCounts.entries) {
      final chapterIdx = entry.key;
      final pagesInChapter = entry.value;

      if (targetPageInBook <= accumulatedPages + pagesInChapter) {
        final pageInChapter = targetPageInBook - accumulatedPages;
        return {
          'chapter': chapterIdx,
          'page': pageInChapter.clamp(0, pagesInChapter - 1),
        };
      }

      accumulatedPages += pagesInChapter;
    }

    return null;
  }

  /// Calculate reading progress percentage
  static double calculateProgress({
    required int currentPageInBook,
    required int totalPages,
  }) {
    if (totalPages <= 0) return 0.0;
    return (currentPageInBook / totalPages).clamp(0.0, 1.0);
  }
}
