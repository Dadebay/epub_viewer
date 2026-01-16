import 'package:flutter/material.dart';

import '../helpers/chapters_bottom_sheet.dart';
import '../models/chapter_model.dart';
import '../show_epub.dart';

/// Helper class for Table of Contents navigation
class EpubTocHelper {
  /// Navigate to selected chapter or subchapter from TOC result
  static Future<void> handleTocSelection({
    required Map<String, dynamic> result,
    required String bookId,
    required int originalChapterIndex,
    required List<LocalChapterModel> chaptersList,
    required Map<int, int> filteredToOriginalIndex,
    required Map<String, int>? Function(int) calculateChapterAndPage,
    required Future<void> Function(int index, int startPage) reloadChapter,
    required void Function(String?) setCurrentSubchapterTitle,
  }) async {
    final chapterIndex = result['chapterIndex'] as int;
    final pageIndex = result['pageIndex'] as int;
    final isSubChapter = result['isSubChapter'] as bool;
    final subchapterTitle = result['subchapterTitle'] as String?;

    if (isSubChapter) {
      setCurrentSubchapterTitle(subchapterTitle);

      final startPage = result['startPage'] as int?;

      if (startPage != null && startPage > 0) {
        final targetInfo = calculateChapterAndPage(startPage - 1);

        if (targetInfo != null) {
          final epubChapterIndex = targetInfo['chapter']!;
          final targetPageInChapter = targetInfo['page']!;

          int chaptersListIndex = epubChapterIndex;
          for (var entry in filteredToOriginalIndex.entries) {
            if (entry.value == epubChapterIndex && !chaptersList[entry.key].isSubChapter) {
              chaptersListIndex = entry.key;
              break;
            }
          }

          await bookProgress.setCurrentChapterIndex(bookId, chaptersListIndex);
          await bookProgress.setCurrentPageIndex(bookId, targetPageInChapter);
          await reloadChapter(chaptersListIndex, targetPageInChapter);
          return;
        }
      }

      // Fallback
      if (chapterIndex == originalChapterIndex) {
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        await reloadChapter(chapterIndex, pageIndex);
      } else {
        await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        await reloadChapter(chapterIndex, pageIndex);
      }
    } else {
      setCurrentSubchapterTitle(null);

      if (chapterIndex != originalChapterIndex) {
        await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        await reloadChapter(chapterIndex, pageIndex);
      } else {
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        await reloadChapter(chapterIndex, pageIndex);
      }
    }
  }

  /// Show TOC bottom sheet
  static Future<Map<String, dynamic>?> showTocBottomSheet({
    required BuildContext context,
    required String bookTitle,
    required String bookId,
    required String imageUrl,
    required List<LocalChapterModel> chapters,
    required Color accentColor,
    required String chapterListTitle,
    required int currentPage,
    required int totalPages,
    required int currentPageInChapter,
    required String? currentSubchapterTitle,
    bool isCalculating = false,
  }) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChaptersBottomSheet(
        title: bookTitle,
        bookId: bookId,
        imageUrl: imageUrl,
        chapters: chapters,
        accentColor: accentColor,
        chapterListTitle: chapterListTitle,
        currentPage: currentPage,
        totalPages: totalPages,
        currentPageInChapter: currentPageInChapter,
        currentSubchapterTitle: currentSubchapterTitle,
        isCalculating: isCalculating,
      ),
    );
  }
}
