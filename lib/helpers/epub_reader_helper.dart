import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../components/constants.dart';
import '../models/chapter_model.dart';
import 'epub_page_calculator.dart';
import 'progress_singleton.dart';

/// Helper class for EPUB reader navigation and state management
class EpubReaderHelper {
  /// Handle page flip logic and update cache
  static void handlePageFlipCache({
    required int totalPages,
    required int originalChapterIdx,
    required bool allChaptersCalculated,
    required Map<int, int> chapterPageCounts,
    required int cachedKnownPagesTotal,
    required int chaptersLength,
    required Function(int) setCachedKnownPagesTotal,
    required Function(int) setTotalPagesInBook,
    required Function(bool) setAllChaptersCalculated,
    required Function() saveCachedPageCounts,
    required Function() updateChapterPageNumbers,
  }) {
    int oldPageCount = chapterPageCounts[originalChapterIdx] ?? 0;
    bool pageCountChanged = oldPageCount != totalPages;

    // Update cache when page count changes (either increase or decrease)
    // This handles font size/theme changes that affect pagination
    if (pageCountChanged) {
      print('📝 Updating chapterPageCounts[$originalChapterIdx]: $oldPageCount -> $totalPages');
      int newCachedTotal = cachedKnownPagesTotal - oldPageCount + totalPages;
      setCachedKnownPagesTotal(newCachedTotal);
      chapterPageCounts[originalChapterIdx] = totalPages;

      setTotalPagesInBook(newCachedTotal);
      if (chapterPageCounts.length >= chaptersLength) {
        setAllChaptersCalculated(true);
      }

      saveCachedPageCounts();
      updateChapterPageNumbers();
    }
  }

  /// Calculate page numbers for display
  static Map<String, int> calculatePageNumbers({
    required Map<int, int> chapterPageCounts,
    required int originalChapterIdx,
    required int currentPage,
    required bool allChaptersCalculated,
    required int totalPagesInBook,
    required int cachedKnownPagesTotal,
  }) {
    int currentPageInBook = EpubPageCalculator.calculateCurrentPageInBook(
      chapterPageCounts: chapterPageCounts,
      currentChapterIndex: originalChapterIdx,
      currentPageInChapter: currentPage,
    );

    int displayTotalPages = EpubPageCalculator.calculateDisplayTotalPages(
      chapterPageCounts: chapterPageCounts,
      currentChapterIndex: originalChapterIdx,
      allChaptersCalculated: allChaptersCalculated,
      totalPagesInBook: totalPagesInBook,
      cachedKnownPagesTotal: cachedKnownPagesTotal,
    );

    return {
      'currentPageInBook': currentPageInBook,
      'displayTotalPages': displayTotalPages,
    };
  }

  /// Handle navigation to next chapter
  static Future<bool> handleNextChapter({
    required bool isLoadingChapter,
    required String bookId,
    required BookProgressSingleton bookProgress,
    required List<LocalChapterModel> chaptersList,
    required Map<int, int> filteredToOriginalIndex,
    required int currentChapterPageCount,
    required bool allChaptersCalculated,
    required Map<int, int> chapterPageCounts,
    required int cachedKnownPagesTotal,
    required Function(int) setCachedKnownPagesTotal,
    required Function(int) setTotalPagesInBook,
    required Function() saveCachedPageCounts,
    required Function() updateChapterPageNumbers,
    required Function({required int index, int startPage}) reLoadChapter,
    required BuildContext context,
  }) async {
    if (isLoadingChapter) return false;

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    if (index < chaptersList.length - 1) {
      int newIndex = index + 1;

      var originalIdx = filteredToOriginalIndex[index] ?? index;
      var currentTotal = currentChapterPageCount;
      if (!allChaptersCalculated && currentTotal > 0 && chapterPageCounts[originalIdx] != currentTotal) {
        int oldCount = chapterPageCounts[originalIdx] ?? 0;
        chapterPageCounts[originalIdx] = currentTotal;
        int newCachedTotal = cachedKnownPagesTotal - oldCount + currentTotal;
        setCachedKnownPagesTotal(newCachedTotal);
        setTotalPagesInBook(newCachedTotal);
        saveCachedPageCounts();
        updateChapterPageNumbers();
      }

      await bookProgress.setCurrentPageIndex(bookId, 0);
      reLoadChapter(index: newIndex, startPage: 0);
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('end_of_book'.tr),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  /// Handle navigation to previous chapter
  static Future<bool> handlePrevChapter({
    required bool isLoadingChapter,
    required String bookId,
    required BookProgressSingleton bookProgress,
    required Map<int, int> filteredToOriginalIndex,
    required int currentChapterPageCount,
    required bool allChaptersCalculated,
    required Map<int, int> chapterPageCounts,
    required int cachedKnownPagesTotal,
    required Function(int) setCachedKnownPagesTotal,
    required Function(int) setTotalPagesInBook,
    required Function() saveCachedPageCounts,
    required Function() updateChapterPageNumbers,
    required Function({required int index, int startPage}) reLoadChapter,
  }) async {
    if (isLoadingChapter) return false;

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    if (index > 0) {
      int newIndex = index - 1;

      var originalIdx = filteredToOriginalIndex[index] ?? index;
      var currentTotal = currentChapterPageCount;
      if (!allChaptersCalculated && currentTotal > 0 && chapterPageCounts[originalIdx] != currentTotal) {
        int oldCount = chapterPageCounts[originalIdx] ?? 0;
        chapterPageCounts[originalIdx] = currentTotal;
        int newCachedTotal = cachedKnownPagesTotal - oldCount + currentTotal;
        setCachedKnownPagesTotal(newCachedTotal);
        setTotalPagesInBook(newCachedTotal);
        saveCachedPageCounts();
        updateChapterPageNumbers();
      }

      final currentPageIndex = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
      reLoadChapter(index: newIndex, startPage: currentPageIndex);
      return true;
    }
    return false;
  }

  /// Handle font size change
  static void handleFontSizeChange({
    required double newSize,
    required GetStorage gs,
    required String bookId,
    required BookProgressSingleton bookProgress,
    required Map<int, int> chapterPageCounts,
    required Function(double) setFontSize,
    required Function(int) setCachedKnownPagesTotal,
    required Function(int) setTotalPagesInBook,
    required Function(bool) setAllChaptersCalculated,
    required Function(int) setCurrentChapterPageCount,
    required Function(int) setAccumulatedPages,
    required Function(bool) setSkipBackgroundCalculation,
    required Function() setState,
    required Function({required int index, int startPage}) reLoadChapter,
  }) {
    setFontSize(newSize);
    gs.write(libFontSize, newSize);

    // Clear page counts cache
    chapterPageCounts.clear();
    setCachedKnownPagesTotal(0);
    setTotalPagesInBook(0);
    setAllChaptersCalculated(false);
    setCurrentChapterPageCount(0);
    setAccumulatedPages(0);
    gs.remove('book_${bookId}_page_counts');

    final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final currentPageIdx = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;

    setSkipBackgroundCalculation(true);
    setState();

    reLoadChapter(index: currentChapterIdx, startPage: currentPageIdx);

    Future.delayed(const Duration(milliseconds: 100), () {
      setSkipBackgroundCalculation(false);
    });
  }

  /// Set screen brightness
  static Future<void> setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
  }

  /// Setup navigation buttons visibility
  static Map<String, bool> getNavButtonsVisibility({
    required String bookId,
    required BookProgressSingleton bookProgress,
    required int chaptersLength,
  }) {
    int index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    return {
      'showPrevious': index > 0,
      'showNext': index < chaptersLength - 1,
    };
  }

  /// Calculate total pages from chapter page counts
  static int calculateTotalFromCounts(Map<int, int> chapterPageCounts) {
    int total = 0;
    for (var count in chapterPageCounts.values) {
      total += count;
    }
    return total;
  }
}
