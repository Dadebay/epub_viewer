import 'package:flutter/material.dart';

import '../helpers/chapters_bottom_sheet.dart';
import '../models/chapter_model.dart';
import '../show_epub.dart';

class EpubTocHelper {
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

      final pageInChapter = pageIndex;

      if (chapterIndex == originalChapterIndex) {
        await bookProgress.setCurrentPageIndex(bookId, pageInChapter);
        await reloadChapter(chapterIndex, pageInChapter);
      } else {
        await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
        await bookProgress.setCurrentPageIndex(bookId, pageInChapter);
        await reloadChapter(chapterIndex, pageInChapter);
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

  static Future<Map<String, dynamic>?> showTocBottomSheet({
    required BuildContext context,
    required String bookTitle,
    required String bookId,
    required String imageUrl,
    required List<LocalChapterModel> chapters,
    required Map<int, int> chapterPageCounts,
    required Map<int, Map<String, int>> subchapterPageMapByChapter,
    required Map<int, int> filteredToOriginalIndex,
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
        chapterPageCounts: chapterPageCounts,
        subchapterPageMapByChapter: subchapterPageMapByChapter,
        filteredToOriginalIndex: filteredToOriginalIndex,
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
