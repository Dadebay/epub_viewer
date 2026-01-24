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
    print('\n╔══════════════════════════════════════════════════════════╗');
    print('║ 📍 HANDLE TOC SELECTION ║');
    print('╠══════════════════════════════════════════════════════════╣');

    final chapterIndex = result['chapterIndex'] as int;
    final pageIndex = result['pageIndex'] as int;
    final isSubChapter = result['isSubChapter'] as bool;
    final subchapterTitle = result['subchapterTitle'] as String?;

    print('║ Result from bottom sheet:');
    print('║   • chapterIndex: $chapterIndex');
    print('║   • pageIndex: $pageIndex');
    print('║   • isSubChapter: $isSubChapter');
    print('║   • subchapterTitle: $subchapterTitle');
    print('║   • startPage from result: ${result['startPage']}');
    print('╠══════════════════════════════════════════════════════════╣');

    if (isSubChapter) {
      setCurrentSubchapterTitle(subchapterTitle);

      final startPage = result['startPage'] as int?;
      print('║ 🔖 SUBCHAPTER NAVIGATION:');
      print('║   • Using startPage: $startPage');

      if (startPage != null && startPage > 0) {
        print('║   • Calculating target from startPage: ${startPage - 1}');
        final targetInfo = calculateChapterAndPage(startPage - 1);
        print('║   • targetInfo result: $targetInfo');
        print('║   • targetInfo result: $targetInfo');

        if (targetInfo != null) {
          final epubChapterIndex = targetInfo['chapter']!;
          final targetPageInChapter = targetInfo['page']!;

          print('║   • epubChapterIndex (from calc): $epubChapterIndex');
          print('║   • targetPageInChapter (from calc): $targetPageInChapter');

          int chaptersListIndex = epubChapterIndex;
          for (var entry in filteredToOriginalIndex.entries) {
            if (entry.value == epubChapterIndex && !chaptersList[entry.key].isSubChapter) {
              chaptersListIndex = entry.key;
              break;
            }
          }

          print('║   • Final chaptersListIndex: $chaptersListIndex');
          print('║   • Will reload chapter at page: $targetPageInChapter');
          print('╚══════════════════════════════════════════════════════════╝');

          await bookProgress.setCurrentChapterIndex(bookId, chaptersListIndex);
          await bookProgress.setCurrentPageIndex(bookId, targetPageInChapter);
          await reloadChapter(chaptersListIndex, targetPageInChapter);
          return;
        } else {
          print('║   ⚠️  targetInfo is NULL - using fallback navigation');
        }
      } else {
        print('║   ⚠️  startPage is NULL or 0 - using fallback navigation');
      }

      // Fallback
      print('║ 🔄 FALLBACK NAVIGATION:');
      print('║   • chapterIndex: $chapterIndex');
      print('║   • pageIndex: $pageIndex');
      print('║   • originalChapterIndex: $originalChapterIndex');
      print('╚══════════════════════════════════════════════════════════╝');

      if (chapterIndex == originalChapterIndex) {
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        await reloadChapter(chapterIndex, pageIndex);
      } else {
        await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        await reloadChapter(chapterIndex, pageIndex);
      }
    } else {
      print('║ 📖 MAIN CHAPTER NAVIGATION:');
      print('║   • chapterIndex: $chapterIndex');
      print('║   • pageIndex: $pageIndex');
      print('╚══════════════════════════════════════════════════════════╝');

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
