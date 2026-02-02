import 'dart:developer';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import '../models/chapter_model.dart';

class EpubPaginationHelper {
  EpubPaginationHelper({
    required this.epubBook,
    required this.fontSize,
    required this.selectedTextStyle,
    required this.fontColor,
  });

  final EpubBook epubBook;
  final Color fontColor;
  final double fontSize;
  final String selectedTextStyle;

  Map<String, int>? calculateChapterAndPageFromBookPage(
    int targetPageInBook,
    Map<int, int> chapterPageCounts,
  ) {
    if (chapterPageCounts.isEmpty) {
      return null;
    }

    int accumulatedPages = 0;
    for (int chapterIndex = 0; chapterIndex < _chapters.length; chapterIndex++) {
      if (!chapterPageCounts.containsKey(chapterIndex)) {
        return null;
      }

      int pagesInChapter = chapterPageCounts[chapterIndex]!;
      int nextAccumulated = accumulatedPages + pagesInChapter;

      if (targetPageInBook >= accumulatedPages && targetPageInBook < nextAccumulated) {
        int pageInChapter = targetPageInBook - accumulatedPages;

        return {'chapter': chapterIndex, 'page': pageInChapter};
      }

      accumulatedPages = nextAccumulated;
    }

    return null;
  }

  void updateChapterPageNumbers(
    List<LocalChapterModel> chaptersList,
    Map<int, int> chapterPageCounts,
    Map<int, int> filteredToOriginalIndex,
  ) {
    for (int i = 0; i < chaptersList.length; i++) {
      final originalIdx = filteredToOriginalIndex[i] ?? i;
      final isSub = chaptersList[i].isSubChapter;

      if (!isSub) {
        int accumulated = 0;
        for (int j = 0; j < originalIdx; j++) {
          if (chapterPageCounts.containsKey(j)) {
            accumulated += chapterPageCounts[j]!;
          }
        }

        final pageCount = chapterPageCounts[originalIdx] ?? 0;
        final startPage = pageCount > 0 ? accumulated + 1 : 0;

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
        final parentIdx = chaptersList[i].parentChapterIndex;
        int startPage = 0;
        int endPage = 0;
        int calculatedPageInChapter = 0;

        if (parentIdx >= 0 && parentIdx < chaptersList.length) {
          final parentOriginalIdx = filteredToOriginalIndex[parentIdx] ?? parentIdx;

          final parentPageCount = chapterPageCounts[parentOriginalIdx] ?? 0;

          int parentStart = 0;
          for (int j = 0; j < parentOriginalIdx; j++) {
            if (chapterPageCounts.containsKey(j)) {
              parentStart += chapterPageCounts[j]!;
            }
          }
          parentStart = parentPageCount > 0 ? parentStart + 1 : 0;

          int subIdx = 0;
          int subChapterCount = 0;

          for (int j = 0; j < chaptersList.length; j++) {
            if (chaptersList[j].isSubChapter && chaptersList[j].parentChapterIndex == parentIdx) {
              if (j == i) {
                subIdx = subChapterCount;
              }
              subChapterCount++;
            }
          }

          if (parentStart > 0 && subChapterCount > 0) {
            if (parentPageCount <= 1 || parentPageCount < subChapterCount) {
              int nextMainChapterStart = 0;
              for (int k = parentIdx + 1; k < chaptersList.length; k++) {
                if (!chaptersList[k].isSubChapter) {
                  nextMainChapterStart = chaptersList[k].startPage;
                  break;
                }
              }

              int effectiveRange = 0;
              if (nextMainChapterStart > parentStart) {
                effectiveRange = nextMainChapterStart - parentStart;
              } else {
                effectiveRange = subChapterCount + 1;
              }

              if (effectiveRange > 1) {
                double pagesPerSub = effectiveRange / (subChapterCount + 1);
                calculatedPageInChapter = (pagesPerSub * (subIdx + 1)).round();
                if (calculatedPageInChapter >= effectiveRange) {
                  calculatedPageInChapter = effectiveRange - 1;
                }
              } else {
                calculatedPageInChapter = subIdx;
              }
            } else if (parentPageCount > 0) {
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
          pageCount: endPage > 0 ? 1 : 0,
          parentChapterIndex: chaptersList[i].parentChapterIndex,
          pageInChapter: calculatedPageInChapter,
        );
      }
    }
  }

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

  Future<int> countPages(String html, double maxWidth, double maxHeight, {Stopwatch? stopwatch}) async {
    final document = parse(html);
    List<InlineSpan> spans = [];

    final timer = stopwatch ?? (Stopwatch()..start());

    for (var node in document.body!.nodes) {
      if (timer.elapsedMilliseconds > 25) {
        await Future.delayed(Duration.zero);
        timer.reset();
        timer.start();
      }
      spans.add(await _parseNodeForCount(node, maxWidth, maxHeight, timer));
    }

    return _paginateAndCount(spans, maxWidth, maxHeight, timer);
  }

  Future<Map<int, int>> precalculateAllChapters({
    required Map<int, int> existingPageCounts,
    required Size pageSize,
    required Function(int chapter, int pages) onChapterCalculated,
    required bool Function() shouldStop,
    List<int>? priorityList,
  }) async {
    final overallStart = DateTime.now();
    final totalChapters = _chapters.length;
    final contentWidth = pageSize.width - 18.w;
    final contentHeight = pageSize.height - 100.h;
    final chapterPageCounts = Map<int, int>.from(existingPageCounts);

    final indicesToCalculate = priorityList ?? List.generate(totalChapters, (i) => i);
    final stopwatch = Stopwatch()..start();

    for (int i in indicesToCalculate) {
      if (shouldStop()) {
        break;
      }

      if (chapterPageCounts.containsKey(i)) {
        continue;
      }

      try {
        final html = buildChapterHtml(i);
        final pages = await countPages(html, contentWidth, contentHeight, stopwatch: stopwatch);
        chapterPageCounts[i] = pages;

        onChapterCalculated(i, pages);
      } catch (e, st) {
        log('⚠️ Precalc error chapter $i: $e\n$st');
      }
    }

    final overallEnd = DateTime.now();
    final totalDuration = overallEnd.difference(overallStart).inMilliseconds;
    final calculatedCount = chapterPageCounts.length;

    return chapterPageCounts;
  }

  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];

  Future<InlineSpan> _parseNodeForCount(dom.Node node, double maxWidth, double maxHeight, Stopwatch timer) async {
    if (timer.elapsedMilliseconds > 25) {
      await Future.delayed(Duration.zero);
      timer.reset();
      timer.start();
    }

    if (node is dom.Text) {
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
          children.add(await _parseNodeForCount(child, maxWidth, maxHeight, timer));
        }
        return TextSpan(children: children);
      }

      if (node.localName == 'h1' || node.localName == 'h2' || node.localName == 'h3') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNodeForCount(child, maxWidth, maxHeight, timer));
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
        children.add(await _parseNodeForCount(child, maxWidth, maxHeight, timer));
      }
      return TextSpan(children: children);
    }

    return const TextSpan(text: '');
  }

  Future<int> _paginateAndCount(List<InlineSpan> allSpans, double maxWidth, double maxHeight, Stopwatch timer) async {
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
      if (timer.elapsedMilliseconds > 25) {
        await Future.delayed(Duration.zero);
        timer.reset();
        timer.start();
      }
      flatten(s);
    }

    int pageCount = 0;
    List<InlineSpan> currentPageSpans = [];
    double currentHeight = 0;

    for (var span in flatSpans) {
      if (timer.elapsedMilliseconds > 25) {
        await Future.delayed(Duration.zero);
        timer.reset();
        timer.start();
      }
      if (span is WidgetSpan) {
        double spanHeight = 200;
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
}
