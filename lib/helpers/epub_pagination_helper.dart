import 'dart:developer';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import '../models/chapter_model.dart';

/// Helper class for EPUB pagination calculations
class EpubPaginationHelper {
  final EpubBook epubBook;
  final double fontSize;
  final String selectedTextStyle;
  final Color fontColor;

  EpubPaginationHelper({
    required this.epubBook,
    required this.fontSize,
    required this.selectedTextStyle,
    required this.fontColor,
  });

  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];

  /// Calculate which chapter and page corresponds to a page in the book
  Map<String, int>? calculateChapterAndPageFromBookPage(
    int targetPageInBook,
    Map<int, int> chapterPageCounts,
  ) {
    print('\n╔══════════════════════════════════════════════════════════╗');
    print('║ 🧮 CALCULATE CHAPTER & PAGE FROM BOOK PAGE ║');
    print('╠══════════════════════════════════════════════════════════╣');
    print('║ Target Page In Book: $targetPageInBook');
    print('║ Chapter Page Counts: $chapterPageCounts');
    print('╠══════════════════════════════════════════════════════════╣');

    if (chapterPageCounts.isEmpty) {
      print('║ ⚠️  chapterPageCounts is empty - returning null');
      print('╚══════════════════════════════════════════════════════════╝');
      return null;
    }

    int accumulatedPages = 0;
    for (int chapterIndex = 0; chapterIndex < _chapters.length; chapterIndex++) {
      if (!chapterPageCounts.containsKey(chapterIndex)) {
        print('║ ⚠️  Missing page count for chapter $chapterIndex - returning null');
        print('╚══════════════════════════════════════════════════════════╝');
        return null;
      }

      int pagesInChapter = chapterPageCounts[chapterIndex]!;
      int nextAccumulated = accumulatedPages + pagesInChapter;

      print('║ Chapter $chapterIndex: pages $accumulatedPages to ${nextAccumulated - 1} (count: $pagesInChapter)');

      // Check if target page is in this chapter
      if (targetPageInBook >= accumulatedPages && targetPageInBook < nextAccumulated) {
        int pageInChapter = targetPageInBook - accumulatedPages;

        print('╠══════════════════════════════════════════════════════════╣');
        print('║ ✅ FOUND TARGET IN CHAPTER $chapterIndex');
        print('║   • Page In Chapter: $pageInChapter');
        print('╚══════════════════════════════════════════════════════════╝');

        return {'chapter': chapterIndex, 'page': pageInChapter};
      }

      accumulatedPages = nextAccumulated;
    }

    print('║ ⚠️  Target page $targetPageInBook not found in any chapter');
    print('╚══════════════════════════════════════════════════════════╝');
    return null;
  }

  /// Update chapter list with calculated page numbers
  void updateChapterPageNumbers(
    List<LocalChapterModel> chaptersList,
    Map<int, int> chapterPageCounts,
    Map<int, int> filteredToOriginalIndex,
  ) {
    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║ 📊 UPDATE CHAPTER PAGE NUMBERS                            ║');
    print('╠═══════════════════════════════════════════════════════════╣');
    print('║ Total chapters: ${chaptersList.length}');
    print('║ Chapter page counts: $chapterPageCounts');
    print('╚═══════════════════════════════════════════════════════════╝');

    for (int i = 0; i < chaptersList.length; i++) {
      // Map filtered index back to original EPUB chapter index
      final originalIdx = filteredToOriginalIndex[i] ?? i;
      final isSub = chaptersList[i].isSubChapter;

      if (!isSub) {
        // Main chapter: calculate start from accumulated pages of previous chapters
        int accumulated = 0;
        for (int j = 0; j < originalIdx; j++) {
          if (chapterPageCounts.containsKey(j)) {
            accumulated += chapterPageCounts[j]!;
          }
        }

        final pageCount = chapterPageCounts[originalIdx] ?? 0;
        final startPage = pageCount > 0 ? accumulated + 1 : 0; // 1-indexed; 0 if unknown

        print('📖 MAIN CHAPTER [$i]: "${chaptersList[i].chapter}"');
        print('   Original idx: $originalIdx');
        print('   Accumulated: $accumulated');
        print('   Page count: $pageCount');
        print('   Start page: $startPage');

        chaptersList[i] = LocalChapterModel(
          chapter: chaptersList[i].chapter,
          isSubChapter: isSub,
          startPage: startPage,
          endPage: pageCount > 0 ? (startPage + pageCount - 1) : 0,
          pageCount: pageCount,
          parentChapterIndex: chaptersList[i].parentChapterIndex,
          pageInChapter: chaptersList[i].pageInChapter,
        );
      } else {
        // Sub-chapter: calculate position based on parent's actual page count
        final parentIdx = chaptersList[i].parentChapterIndex;
        int startPage = 0;
        int endPage = 0;
        int calculatedPageInChapter = 0;

        print('📑 SUBCHAPTER [$i]: "${chaptersList[i].chapter}"');
        print('   Parent idx: $parentIdx');

        if (parentIdx >= 0 && parentIdx < chaptersList.length) {
          // Get parent's original EPUB index
          final parentOriginalIdx = filteredToOriginalIndex[parentIdx] ?? parentIdx;

          // Get parent's page count from chapterPageCounts (not from chaptersList which may be stale)
          final parentPageCount = chapterPageCounts[parentOriginalIdx] ?? 0;

          // Calculate parent's start page
          int parentStart = 0;
          for (int j = 0; j < parentOriginalIdx; j++) {
            if (chapterPageCounts.containsKey(j)) {
              parentStart += chapterPageCounts[j]!;
            }
          }
          parentStart = parentPageCount > 0 ? parentStart + 1 : 0;

          int subIdx = 0;
          int subChapterCount = 0;

          // First pass: count total and find current sub-chapter's position
          for (int j = 0; j < chaptersList.length; j++) {
            if (chaptersList[j].isSubChapter && chaptersList[j].parentChapterIndex == parentIdx) {
              if (j == i) {
                subIdx = subChapterCount; // This sub-chapter's index (0, 1, 2...)
              }
              subChapterCount++;
            }
          }

          // Calculate proportional position within parent's pages
          if (parentStart > 0 && subChapterCount > 0) {
            // CRITICAL FIX: If parent chapter's page count is too small to fit all subchapters,
            // this means subchapter content is in separate EPUB chapters.
            // In this case, calculate position based on the total pages of subsequent chapters.
            if (parentPageCount <= 1 || parentPageCount < subChapterCount) {
              // Find the next main chapter's start page to calculate the actual range
              int nextMainChapterStart = 0;
              for (int k = parentIdx + 1; k < chaptersList.length; k++) {
                if (!chaptersList[k].isSubChapter) {
                  nextMainChapterStart = chaptersList[k].startPage;
                  break;
                }
              }

              // Calculate the effective page range for subchapters
              int effectiveRange = 0;
              if (nextMainChapterStart > parentStart) {
                effectiveRange = nextMainChapterStart - parentStart;
              } else {
                // If no next main chapter found, estimate based on subchapter count
                effectiveRange = subChapterCount + 1;
              }

              // Distribute subchapters across the effective range
              if (effectiveRange > 1) {
                double pagesPerSub = effectiveRange / (subChapterCount + 1);
                calculatedPageInChapter = (pagesPerSub * (subIdx + 1)).round();
                if (calculatedPageInChapter >= effectiveRange) {
                  calculatedPageInChapter = effectiveRange - 1;
                }
              } else {
                // Fallback: just use subIdx
                calculatedPageInChapter = subIdx;
              }
            } else if (parentPageCount > 0) {
              // Normal case: parent has enough pages
              double pagesPerSubChapter = parentPageCount / (subChapterCount + 1);

              if (pagesPerSubChapter < 1 && parentPageCount > subChapterCount) {
                pagesPerSubChapter = 1;
              }

              calculatedPageInChapter = (pagesPerSubChapter * (subIdx + 1)).round();

              if (calculatedPageInChapter <= subIdx && parentPageCount > subIdx) {
                calculatedPageInChapter = subIdx;
              }

              if (calculatedPageInChapter >= parentPageCount) {
                calculatedPageInChapter = parentPageCount - 1;
              }
            } else {
              calculatedPageInChapter = subIdx;
            }

            startPage = parentStart + calculatedPageInChapter;
            endPage = startPage;
          }
        }

        chaptersList[i] = LocalChapterModel(
          chapter: chaptersList[i].chapter,
          isSubChapter: isSub,
          startPage: startPage,
          endPage: endPage,
          pageCount: endPage > 0 ? 1 : 0, // show as single start point
          parentChapterIndex: chaptersList[i].parentChapterIndex,
          pageInChapter: calculatedPageInChapter,
        );
      }
    }
  }

  /// Build HTML content for a specific chapter including sub-chapters
  String buildChapterHtml(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return '';

    String content = _chapters[chapterIndex].HtmlContent ?? '';
    final subChapters = _chapters[chapterIndex].SubChapters;

    if (subChapters != null && subChapters.isNotEmpty) {
      for (var sub in subChapters) {
        content += sub.HtmlContent ?? '';
      }
    }

    return content;
  }

  /// Count pages for given HTML content with specific dimensions
  Future<int> countPages(String html, double maxWidth, double maxHeight) async {
    final document = parse(html);
    List<InlineSpan> spans = [];

    for (var node in document.body!.nodes) {
      spans.add(await _parseNodeForCount(node, maxWidth, maxHeight));
    }

    return _paginateAndCount(spans, maxWidth, maxHeight);
  }

  /// Parse HTML node for page counting
  Future<InlineSpan> _parseNodeForCount(dom.Node node, double maxWidth, double maxHeight) async {
    if (node is dom.Text) {
      // Replace ALL whitespace (including newlines) with single space
      String text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.trim().isEmpty) return const TextSpan(text: '');

      return TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: selectedTextStyle,
          height: 1.3,
          letterSpacing: 0,
          wordSpacing: 0,
          color: fontColor,
        ),
      );
    }

    if (node is dom.Element) {
      if (node.localName == 'img') {
        // Approximate image height to keep count lightweight
        return WidgetSpan(
          child: SizedBox(
            width: maxWidth * 0.9,
            height: maxHeight * 0.4,
          ),
        );
      }

      if (node.localName == 'br') {
        return const TextSpan(text: "\n");
      }

      if (node.localName == 'p' || node.localName == 'div') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNodeForCount(child, maxWidth, maxHeight));
        }
        return TextSpan(children: children);
      }

      if (node.localName == 'h1' || node.localName == 'h2' || node.localName == 'h3') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNodeForCount(child, maxWidth, maxHeight));
        }
        return TextSpan(
          children: children,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1,
            color: fontColor,
          ),
        );
      }

      List<InlineSpan> children = [];
      for (var child in node.nodes) {
        children.add(await _parseNodeForCount(child, maxWidth, maxHeight));
      }
      return TextSpan(children: children);
    }

    return const TextSpan(text: '');
  }

  /// Paginate and count total pages from spans
  int _paginateAndCount(List<InlineSpan> allSpans, double maxWidth, double maxHeight) {
    List<InlineSpan> flatSpans = [];

    void flatten(InlineSpan span) {
      if (span is TextSpan) {
        if (span.children != null && span.children!.isNotEmpty) {
          for (var child in span.children!) flatten(child);
        } else if (span.text != null && span.text!.isNotEmpty) {
          flatSpans.add(span);
        }
      } else if (span is WidgetSpan) {
        flatSpans.add(span);
      }
    }

    for (var s in allSpans) {
      flatten(s);
    }

    int pageCount = 0;
    List<InlineSpan> currentPageSpans = [];
    double currentHeight = 0;

    for (var span in flatSpans) {
      if (span is WidgetSpan) {
        double spanHeight = 200; // Approximate; enough for counting
        if (currentHeight + spanHeight > maxHeight && currentPageSpans.isNotEmpty) {
          pageCount++;
          currentPageSpans.clear();
          currentHeight = 0;
        }
        currentPageSpans.add(span);
        currentHeight += spanHeight;
      } else if (span is TextSpan && span.text != null) {
        final painter = TextPainter(
          text: TextSpan(text: span.text, style: span.style),
          textDirection: TextDirection.ltr,
          textScaleFactor: 1.0,
        );
        painter.layout(maxWidth: maxWidth);

        if (currentHeight + painter.height <= maxHeight) {
          currentPageSpans.add(span);
          currentHeight += painter.height;
        } else {
          final lines = painter.computeLineMetrics();
          double chunkHeight = 0;

          for (final line in lines) {
            if (currentHeight + chunkHeight + line.height > maxHeight) {
              if (chunkHeight > 0 || currentPageSpans.isNotEmpty) {
                pageCount++;
                currentPageSpans.clear();
                currentHeight = 0;
                chunkHeight = 0;
              }
            }
            chunkHeight += line.height;
          }

          currentHeight += chunkHeight;
          currentPageSpans.add(span);
        }
        painter.dispose();
      }
    }

    if (currentPageSpans.isNotEmpty) {
      pageCount++;
    }

    return pageCount;
  }

  /// Precalculate all chapters' page counts in background
  Future<Map<int, int>> precalculateAllChapters({
    required Map<int, int> existingPageCounts,
    required Size pageSize,
    required Function(int chapter, int pages) onChapterCalculated,
    required bool Function() shouldStop,
  }) async {
    final totalChapters = _chapters.length;
    final contentWidth = pageSize.width - 18.w;
    final contentHeight = pageSize.height - 100.h;
    final chapterPageCounts = Map<int, int>.from(existingPageCounts);

    for (int i = 0; i < totalChapters; i++) {
      // Stop if widget is disposed
      if (shouldStop()) {
        break;
      }

      if (chapterPageCounts.containsKey(i)) {
        continue; // Already known from cache or reading
      }

      try {
        final html = buildChapterHtml(i);
        final pages = await countPages(html, contentWidth, contentHeight);
        chapterPageCounts[i] = pages;

        // Notify callback
        onChapterCalculated(i, pages);
      } catch (e, st) {
        log('⚠️ Precalc error chapter $i: $e\n$st');
      }

      // Yield to UI between chapters - only every 5 chapters to speed up
      if (i % 5 == 0 && i > 0) {
        await Future.delayed(Duration(milliseconds: 10));
      }
    }

    return chapterPageCounts;
  }
}
