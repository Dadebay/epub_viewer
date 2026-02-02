import 'dart:developer';
import 'package:cosmos_epub/helpers/epub_chapter_fixer.dart';
import 'package:cosmos_epub/helpers/functions.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import '../models/chapter_model.dart';
import '../helpers/progress_singleton.dart';

class EpubChapterHelper {
  EpubChapterHelper({
    required this.epubBook,
    required this.bookId,
    required this.bookProgress,
  });

  final String bookId;
  final BookProgressSingleton bookProgress;
  final EpubBook epubBook;

  Future<Map<String, dynamic>> buildChaptersList({
    required Map<int, int> chapterPageCounts,
  }) async {
    List<LocalChapterModel> chaptersList = [];
    Map<int, int> filteredToOriginalIndex = {};

    Map<String, String> navTitles = {};
    if (epubBook.Schema?.Navigation?.NavMap?.Points != null) {
      for (var point in epubBook.Schema!.Navigation!.NavMap!.Points!) {
        if (point.Content?.Source != null && point.NavigationLabels != null && point.NavigationLabels!.isNotEmpty) {
          String source = point.Content!.Source!;
          String fileName = source.split('#').first;
          fileName = fileName.split('/').last;

          String? labelText = point.NavigationLabels!.first.Text;
          if (labelText != null && labelText.isNotEmpty) {
            navTitles[fileName] = labelText;
          }
        }
      }
    }

    for (int i = 0; i < _chapters.length; i++) {
      var chapter = _chapters[i];

      String? chapterTitle = chapter.Title;

      final needsExtraction = chapterTitle == null ||
          chapterTitle.isEmpty ||
          chapterTitle.contains('_split_') ||
          chapterTitle.toLowerCase().startsWith('index split') ||
          chapterTitle.contains('.html') ||
          chapterTitle.contains('.xhtml') ||
          chapterTitle.toLowerCase() == 'titlepage' ||
          chapterTitle.toLowerCase() == 'index' ||
          chapterTitle.toLowerCase() == 'cover';

      final isBasicChapterTitle = chapterTitle != null && RegExp(r'^Chapter \d+$', caseSensitive: false).hasMatch(chapterTitle);

      if (needsExtraction || isBasicChapterTitle) {
        String? contentRef = chapter.ContentFileName;
        if (contentRef != null) {
          String fileName = contentRef.split('/').last.split('#').first;
          if (navTitles.containsKey(fileName)) {
            String navTitle = navTitles[fileName]!;

            if (navTitle.isNotEmpty && navTitle != chapterTitle) {
              chapterTitle = navTitle;
            }
          }
        }
      }

      int chapterStartPage = 1;
      int accumulatedPages = 0;

      for (int j = 0; j < i; j++) {
        accumulatedPages += chapterPageCounts[j] ?? 0;
      }
      chapterStartPage = accumulatedPages + 1;

      chaptersList.add(LocalChapterModel(
        chapter: chapterTitle ?? 'Chapter ${i + 1}',
        isSubChapter: false,
        startPage: chapterPageCounts.containsKey(i) ? chapterStartPage : 0,
        pageCount: chapterPageCounts[i] ?? 0,
      ));
      final listIndex = chaptersList.length - 1;
      filteredToOriginalIndex[listIndex] = i;

      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        int subChapterCount = chapter.SubChapters!.length;
        int mainChapterPages = chapterPageCounts[i] ?? 0;

        Set<int> usedPages = {};

        for (int subIdx = 0; subIdx < chapter.SubChapters!.length; subIdx++) {
          var subChapter = chapter.SubChapters![subIdx];
          String? subTitle = subChapter.Title;
          if (subTitle != null && subTitle.isNotEmpty) {
            final subChapterIndex = chaptersList.length;

            int subChapterStartPage = chapterStartPage;
            int pageInChapter = 0;

            if (mainChapterPages > 0 && subChapterCount > 0) {
              int pagesPerSubChapter = mainChapterPages ~/ (subChapterCount + 1);

              if (pagesPerSubChapter == 0 && mainChapterPages > subChapterCount) {
                pagesPerSubChapter = 1;
              }

              pageInChapter = pagesPerSubChapter * (subIdx + 1);

              int attemptedPage = pageInChapter;
              while (usedPages.contains(attemptedPage) && attemptedPage < mainChapterPages) {
                attemptedPage++;
              }

              if (attemptedPage < mainChapterPages) {
                pageInChapter = attemptedPage;
              }

              subChapterStartPage = chapterStartPage + pageInChapter;

              if (subChapterStartPage > chapterStartPage + mainChapterPages - 1) {
                subChapterStartPage = chapterStartPage + mainChapterPages - 1;
                pageInChapter = mainChapterPages - 1;
              }

              usedPages.add(pageInChapter);
            }

            chaptersList.add(LocalChapterModel(
              chapter: subTitle,
              isSubChapter: true,
              startPage: chapterPageCounts.containsKey(i) ? subChapterStartPage : 0,
              pageCount: 0,
              parentChapterIndex: listIndex,
              pageInChapter: pageInChapter,
            ));

            filteredToOriginalIndex[subChapterIndex] = i;
          }
        }
      }
    }

    return {
      'chaptersList': chaptersList,
      'filteredToOriginalIndex': filteredToOriginalIndex,
    };
  }

  Future<Map<String, dynamic>> getChapterContent({
    required int chapterIndex,
    required Map<int, int> filteredToOriginalIndex,
  }) async {
    final originalChapterIndex = filteredToOriginalIndex[chapterIndex] ?? chapterIndex;

    String content = '';
    String textContent = '';
    TextDirection textDirection = TextDirection.ltr;

    try {
      if (originalChapterIndex >= 0 && originalChapterIndex < _chapters.length) {
        content = _chapters[originalChapterIndex].HtmlContent ?? '';

        List<EpubChapter>? subChapters = _chapters[originalChapterIndex].SubChapters;
        if (subChapters != null && subChapters.isNotEmpty) {
          for (var subChapter in subChapters) {
            content += subChapter.HtmlContent ?? '';
          }
        }
      } else {
        content = '<html><body><p>Chapter not found</p></body></html>';
      }
    } catch (e) {
      content = '<html><body><p>Error loading chapter: $e</p></body></html>';
    }

    textContent = parse(content).documentElement!.text;
    textContent = textContent.replaceAll('Unknown', '').trim();

    textDirection = RTLHelper.getTextDirection(textContent);

    return {
      'htmlContent': content,
      'textContent': textContent,
      'textDirection': textDirection,
      'originalChapterIndex': originalChapterIndex,
    };
  }

  int calculateAccumulatedPages({
    required int originalChapterIndex,
    required Map<int, int> chapterPageCounts,
  }) {
    int accumulated = 0;
    for (int i = 0; i < originalChapterIndex; i++) {
      if (chapterPageCounts.containsKey(i)) {
        accumulated += chapterPageCounts[i]!;
      }
    }
    return accumulated;
  }

  int determineTargetChapter({
    required bool isInit,
    required int requestedIndex,
    required int totalChapters,
    int? starterPageInBook,
    int? starterChapter,
    required Map<int, int> chapterPageCounts,
    required Function(int pageInBook)? calculateChapterFromPage,
  }) {
    int targetIndex = requestedIndex;

    if (isInit) {
      final progress = bookProgress.getBookProgress(bookId);
      final savedChapter = progress.currentChapterIndex ?? 0;
      final savedPage = progress.currentPageIndex ?? 0;
      final hasProgress = (savedChapter != 0) || (savedPage != 0);

      if (starterPageInBook != null && chapterPageCounts.isNotEmpty && calculateChapterFromPage != null) {
        try {
          targetIndex = calculateChapterFromPage(starterPageInBook);
        } catch (e) {
          targetIndex = hasProgress ? savedChapter : 0;
        }
      } else if (hasProgress) {
        targetIndex = savedChapter;
      } else if (starterChapter != null && starterChapter >= 0 && starterChapter < totalChapters) {
        targetIndex = starterChapter;
      } else {
        targetIndex = 0;
      }
    }

    if (targetIndex < 0 || targetIndex >= totalChapters) {
      targetIndex = 0;
    }

    return targetIndex;
  }

  String? updateSubchapterTitleForPage({
    required int currentChapterIndex,
    required int pageInChapter,
    required List<LocalChapterModel> chaptersList,
  }) {
    String? foundSubchapterTitle;

    List<LocalChapterModel> currentSubchapters = [];
    for (int i = 0; i < chaptersList.length; i++) {
      final chapter = chaptersList[i];
      if (chapter.isSubChapter && chapter.parentChapterIndex == currentChapterIndex) {
        currentSubchapters.add(chapter);
      }
    }

    if (currentSubchapters.isEmpty) {
      return null;
    }

    currentSubchapters.sort((a, b) => a.pageInChapter.compareTo(b.pageInChapter));

    for (int i = 0; i < currentSubchapters.length; i++) {
      final subchapter = currentSubchapters[i];

      if (pageInChapter >= subchapter.pageInChapter) {
        if (i + 1 < currentSubchapters.length) {
          final nextSubchapter = currentSubchapters[i + 1];

          if (pageInChapter < nextSubchapter.pageInChapter) {
            foundSubchapterTitle = subchapter.chapter;
            break;
          }
        } else {
          foundSubchapterTitle = subchapter.chapter;
        }
      }
    }

    return foundSubchapterTitle;
  }

  String? updateSubchapterTitleForPageWithMap({
    required int currentChapterIndex,
    required int pageInChapter,
    required List<LocalChapterModel> chaptersList,
    Map<String, int>? subchapterPageMap,
  }) {
    if (subchapterPageMap == null || subchapterPageMap.isEmpty) {
      return null;
    }

    final sortedEntries = subchapterPageMap.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    String? foundSubchapterTitle;

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final subchapterTitle = entry.key;
      final subchapterStartPage = entry.value;

      if (pageInChapter >= subchapterStartPage) {
        if (i + 1 < sortedEntries.length) {
          final nextEntry = sortedEntries[i + 1];
          final nextStartPage = nextEntry.value;

          if (pageInChapter < nextStartPage) {
            foundSubchapterTitle = subchapterTitle;
            break;
          }
        } else {
          foundSubchapterTitle = subchapterTitle;
        }
      }
    }

    return foundSubchapterTitle;
  }

  String getChapterTitleForDisplay({
    required int currentChapterIndex,
    required List<LocalChapterModel> chaptersList,
    String? currentSubchapterTitle,
  }) {
    if (currentSubchapterTitle != null && currentSubchapterTitle.isNotEmpty) {
      return currentSubchapterTitle;
    }

    if (currentChapterIndex < 0 || currentChapterIndex >= chaptersList.length) {
      return '';
    }

    return chaptersList[currentChapterIndex].chapter;
  }

  void initializeEpubStructure() {
    log('📚 EPUB Debug Info:');
    log('   Title: ${epubBook.Title}');
    log('   Author: ${epubBook.Author}');
    log('   Total Chapters: ${epubBook.Chapters?.length ?? 0}');
    log('   Schema: ${epubBook.Schema}');
    log('   Content: ${epubBook.Content != null ? "Present" : "Null"}');

    if (epubBook.Content != null) {
      log('   HTML Files: ${epubBook.Content!.Html?.keys.length ?? 0}');
      log('   CSS Files: ${epubBook.Content!.Css?.keys.length ?? 0}');
      log('   Images: ${epubBook.Content!.Images?.keys.length ?? 0}');
    }

    EpubChapterFixer.fixChaptersIfNeeded(epubBook);
    log('📚 After fix - Total Chapters: ${epubBook.Chapters?.length ?? 0}');
  }

  String getBookTitle() {
    return epubBook.Title ?? 'Unknown Book';
  }

  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];
}
