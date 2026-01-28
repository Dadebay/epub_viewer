import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';

import '../helpers/epub_page_calculator.dart';
import '../helpers/functions.dart';
import '../show_epub.dart';

/// Helper class for loading chapter content
class EpubContentHelper {
  /// Load chapter content by index
  static Map<String, dynamic> loadChapterContent({
    required List<EpubChapter> chapters,
    required int chapterIndex,
    required Map<int, int> filteredToOriginalIndex,
    required Map<int, int> chapterPageCounts,
    required List<dynamic> chaptersList,
    required String bookId,
    required bool allChaptersCalculated,
    required int totalPagesInBook,
    EpubBook? epubBook,
  }) {
    final originalChapterIndex = filteredToOriginalIndex[chapterIndex] ?? chapterIndex;

    int accumulatedPagesBeforeCurrentChapter = EpubPageCalculator.calculateAccumulatedPages(
      chapterPageCounts,
      originalChapterIndex,
    );

    String content = '';

    try {
      if (originalChapterIndex >= 0 && originalChapterIndex < chapters.length) {
        // First try to get raw HTML from epub content files (includes blockquotes, etc)
        content = _getRawHtmlContent(epubBook, chapters[originalChapterIndex]) ?? '';

        // Fallback to HtmlContent if raw not available
        if (content.isEmpty) {
          content = chapters[originalChapterIndex].HtmlContent ?? '';
        }

        List<EpubChapter>? subChapters = chapters[originalChapterIndex].SubChapters;
        if (subChapters != null && subChapters.isNotEmpty) {
          for (var subChapter in subChapters) {
            final subContent = _getRawHtmlContent(epubBook, subChapter) ?? subChapter.HtmlContent ?? '';
            content += subContent;
          }
        }
      } else {
        content = '<html><body><p>Chapter not found</p></body></html>';
      }
    } catch (e) {
      content = '<html><body><p>Error loading chapter: $e</p></body></html>';
    }

    String textContent = parse(content).documentElement!.text;
    textContent = textContent.replaceAll('Unknown', '').trim();

    TextDirection textDirection = RTLHelper.getTextDirection(textContent);

    final storedPageIndex = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
    final currentPageInBook = accumulatedPagesBeforeCurrentChapter + storedPageIndex + 1;

    // Calculate total pages
    int calculatedTotal = 0;
    for (var count in chapterPageCounts.values) {
      calculatedTotal += count;
    }

    final displayTotalPages = allChaptersCalculated ? totalPagesInBook : (calculatedTotal > 0 ? calculatedTotal : totalPagesInBook);

    return {
      'htmlContent': content,
      'textContent': textContent,
      'textDirection': textDirection,
      'accumulatedPagesBeforeCurrentChapter': accumulatedPagesBeforeCurrentChapter,
      'currentPageInBook': currentPageInBook,
      'displayTotalPages': displayTotalPages,
    };
  }

  /// Get raw HTML content from epub file (includes all elements like blockquote)
  static String? _getRawHtmlContent(EpubBook? epubBook, EpubChapter chapter) {
    if (epubBook == null) return null;

    // Try to find the raw HTML file that corresponds to this chapter
    final contentFileName = chapter.ContentFileName;
    if (contentFileName == null || contentFileName.isEmpty) return null;

    final htmlFiles = epubBook.Content?.Html;
    if (htmlFiles == null) return null;

    // Try exact match first
    if (htmlFiles.containsKey(contentFileName)) {
      final rawContent = htmlFiles[contentFileName]?.Content;
      if (rawContent != null && rawContent.isNotEmpty) {
        // Extract body content from full HTML
        return _extractBodyContent(rawContent);
      }
    }

    // Try matching by filename only (without path)
    final fileName = contentFileName.split('/').last;
    for (var key in htmlFiles.keys) {
      if (key.endsWith(fileName) || key.split('/').last == fileName) {
        final rawContent = htmlFiles[key]?.Content;
        if (rawContent != null && rawContent.isNotEmpty) {
          return _extractBodyContent(rawContent);
        }
      }
    }

    return null;
  }

  /// Extract body content from full HTML document
  static String _extractBodyContent(String fullHtml) {
    try {
      final document = parse(fullHtml);
      final body = document.body;
      if (body != null) {
        // Return inner HTML of body (preserves all elements including blockquote)
        return body.innerHtml;
      }
    } catch (e) {}
    return fullHtml;
  }

  /// Check if string contains HTML
  static bool isHTML(String str) {
    final RegExp htmlRegExp = RegExp('<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlRegExp.hasMatch(str);
  }
}
