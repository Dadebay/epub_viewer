import 'dart:developer';
import 'package:cosmos_epub/helpers/epub_chapter_fixer.dart';
import 'package:cosmos_epub/helpers/functions.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import '../models/chapter_model.dart';
import '../helpers/progress_singleton.dart';

/// Helper class for EPUB chapter loading and navigation
class EpubChapterHelper {
  final EpubBook epubBook;
  final String bookId;
  final BookProgressSingleton bookProgress;

  EpubChapterHelper({
    required this.epubBook,
    required this.bookId,
    required this.bookProgress,
  });

  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];

  /// Build chapters list with proper titles and sub-chapters
  Future<Map<String, dynamic>> buildChaptersList({
    required Map<int, int> chapterPageCounts,
  }) async {
    List<LocalChapterModel> chaptersList = [];
    Map<int, int> filteredToOriginalIndex = {};

    // Try to get chapter titles from Navigation (TOC) first
    Map<String, String> navTitles = {};
    if (epubBook.Schema?.Navigation?.NavMap?.Points != null) {
      for (var point in epubBook.Schema!.Navigation!.NavMap!.Points!) {
        if (point.Content?.Source != null && point.NavigationLabels != null && point.NavigationLabels!.isNotEmpty) {
          // Extract the HTML file name from the Source path
          String source = point.Content!.Source!;
          String fileName = source.split('#').first; // Remove anchor
          fileName = fileName.split('/').last; // Get just the filename
          // Use the first navigation label's text
          String? labelText = point.NavigationLabels!.first.Text;
          if (labelText != null && labelText.isNotEmpty) {
            navTitles[fileName] = labelText;
          }
        }
      }
    }

    // Add all chapters (don't filter by content length)
    for (int i = 0; i < _chapters.length; i++) {
      var chapter = _chapters[i];

      // Use the title from cosmos_epub - it's already extracted properly
      String? chapterTitle = chapter.Title;

      // Only try to improve if title is REALLY generic/useless
      final needsExtraction = chapterTitle == null ||
          chapterTitle.isEmpty ||
          chapterTitle.contains('_split_') ||
          chapterTitle.toLowerCase().startsWith('index split') ||
          chapterTitle.contains('.html') ||
          chapterTitle.contains('.xhtml') ||
          chapterTitle.toLowerCase() == 'titlepage' ||
          chapterTitle.toLowerCase() == 'index' ||
          chapterTitle.toLowerCase() == 'cover';

      // If title is just "Chapter X" (without description), try to get a better one from navigation
      final isBasicChapterTitle = chapterTitle != null && RegExp(r'^Chapter \d+$', caseSensitive: false).hasMatch(chapterTitle);

      if (needsExtraction || isBasicChapterTitle) {
        // Try navigation TOC for a better title
        String? contentRef = chapter.ContentFileName;
        if (contentRef != null) {
          String fileName = contentRef.split('/').last.split('#').first;
          if (navTitles.containsKey(fileName)) {
            String navTitle = navTitles[fileName]!;
            // Use navigation title if it's better (not empty and different)
            if (navTitle.isNotEmpty && navTitle != chapterTitle) {
              chapterTitle = navTitle;
            }
          }
        }
      }

      // Calculate startPage for this chapter based on accumulated pages
      int chapterStartPage = 1; // Default to page 1
      int accumulatedPages = 0;

      // Calculate accumulated pages from all previous chapters
      for (int j = 0; j < i; j++) {
        accumulatedPages += chapterPageCounts[j] ?? 0;
      }
      chapterStartPage = accumulatedPages + 1; // Pages are 1-indexed

      // Add chapter to list with page information
      chaptersList.add(LocalChapterModel(
        chapter: chapterTitle ?? 'Chapter ${i + 1}',
        isSubChapter: false,
        startPage: chapterPageCounts.containsKey(i) ? chapterStartPage : 0,
        pageCount: chapterPageCounts[i] ?? 0,
      ));
      final listIndex = chaptersList.length - 1;
      filteredToOriginalIndex[listIndex] = i;

      // Add sub-chapters if available - each with its own page number
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        int subChapterCount = chapter.SubChapters!.length;
        int mainChapterPages = chapterPageCounts[i] ?? 0;

        // Track which pages already have subchapters assigned
        Set<int> usedPages = {};

        for (int subIdx = 0; subIdx < chapter.SubChapters!.length; subIdx++) {
          var subChapter = chapter.SubChapters![subIdx];
          String? subTitle = subChapter.Title;
          if (subTitle != null && subTitle.isNotEmpty) {
            final subChapterIndex = chaptersList.length;

            // Calculate approximate page for this sub-chapter within the parent chapter
            int subChapterStartPage = chapterStartPage;
            int pageInChapter = 0; // Page within the parent chapter (0-indexed)

            if (mainChapterPages > 0 && subChapterCount > 0) {
              // Each sub-chapter gets roughly equal portion of pages
              // But ensure minimum 1 page difference between subchapters
              int pagesPerSubChapter = mainChapterPages ~/ (subChapterCount + 1);

              // Ensure at least 1 page spacing between subchapters if possible
              if (pagesPerSubChapter == 0 && mainChapterPages > subChapterCount) {
                pagesPerSubChapter = 1;
              }

              pageInChapter = pagesPerSubChapter * (subIdx + 1);

              // If this pageInChapter is already used, try to find next available page
              int attemptedPage = pageInChapter;
              while (usedPages.contains(attemptedPage) && attemptedPage < mainChapterPages) {
                attemptedPage++;
              }

              // If all pages after this are used, just use the calculated page
              if (attemptedPage < mainChapterPages) {
                pageInChapter = attemptedPage;
              }

              subChapterStartPage = chapterStartPage + pageInChapter;

              // Ensure it doesn't exceed chapter bounds
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
            // Map sub-chapter entry back to its parent chapter for loading content
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

  /// Get HTML content for a specific chapter (including sub-chapters)
  Future<Map<String, dynamic>> getChapterContent({
    required int chapterIndex,
    required Map<int, int> filteredToOriginalIndex,
  }) async {
    // Map filtered index to original EPUB chapter index
    final originalChapterIndex = filteredToOriginalIndex[chapterIndex] ?? chapterIndex;

    String content = '';
    String textContent = '';
    TextDirection textDirection = TextDirection.ltr;

    try {
      // Directly access the chapter by original index
      if (originalChapterIndex >= 0 && originalChapterIndex < _chapters.length) {
        content = _chapters[originalChapterIndex].HtmlContent ?? '';

        // Add subchapters content if they exist
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

    // Extract text content for text direction detection
    textContent = parse(content).documentElement!.text;
    textContent = textContent.replaceAll('Unknown', '').trim();

    // Detect text direction for the current content
    textDirection = RTLHelper.getTextDirection(textContent);

    return {
      'htmlContent': content,
      'textContent': textContent,
      'textDirection': textDirection,
      'originalChapterIndex': originalChapterIndex,
    };
  }

  /// Calculate accumulated pages before a specific chapter
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

  /// Determine target chapter index for initialization
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

      // Priority 1: Audio sync (starterPageInBook)
      if (starterPageInBook != null && chapterPageCounts.isNotEmpty && calculateChapterFromPage != null) {
        try {
          targetIndex = calculateChapterFromPage(starterPageInBook);
        } catch (e) {
          targetIndex = hasProgress ? savedChapter : 0;
        }
      }
      // Priority 2: Saved progress from last read
      else if (hasProgress) {
        targetIndex = savedChapter;
      }
      // Priority 3: Explicit starter chapter
      else if (starterChapter != null && starterChapter >= 0 && starterChapter < totalChapters) {
        targetIndex = starterChapter;
      }
      // Priority 4: First chapter
      else {
        targetIndex = 0;
      }
    }

    // Validate bounds
    if (targetIndex < 0 || targetIndex >= totalChapters) {
      targetIndex = 0;
    }

    return targetIndex;
  }

  /// Update subchapter title based on current page position
  String? updateSubchapterTitleForPage({
    required int currentChapterIndex,
    required int pageInChapter,
    required List<LocalChapterModel> chaptersList,
  }) {
    String? foundSubchapterTitle;

    // Collect all subchapters of current chapter
    List<LocalChapterModel> currentSubchapters = [];
    for (int i = 0; i < chaptersList.length; i++) {
      final chapter = chaptersList[i];
      if (chapter.isSubChapter && chapter.parentChapterIndex == currentChapterIndex) {
        currentSubchapters.add(chapter);
      }
    }

    print('🔍 updateSubchapterTitleForPage: chapterIdx=$currentChapterIndex, page=$pageInChapter, found ${currentSubchapters.length} subchapters');

    if (currentSubchapters.isEmpty) {
      return null;
    }

    // Sort by pageInChapter
    currentSubchapters.sort((a, b) => a.pageInChapter.compareTo(b.pageInChapter));

    print('📋 Subchapters for chapter $currentChapterIndex:');
    for (var sub in currentSubchapters) {
      print('   - "${sub.chapter}" starts at page ${sub.pageInChapter}');
    }

    // Find the subchapter we're currently in
    for (int i = 0; i < currentSubchapters.length; i++) {
      final subchapter = currentSubchapters[i];

      // If we're at or after this subchapter's page
      if (pageInChapter >= subchapter.pageInChapter) {
        // Check if there's a next subchapter
        if (i + 1 < currentSubchapters.length) {
          final nextSubchapter = currentSubchapters[i + 1];
          // If we haven't reached the next subchapter yet
          if (pageInChapter < nextSubchapter.pageInChapter) {
            foundSubchapterTitle = subchapter.chapter;
            print('✅ Found subchapter: "${foundSubchapterTitle}" (page $pageInChapter is between ${subchapter.pageInChapter} and ${nextSubchapter.pageInChapter})');
            break;
          }
        } else {
          // This is the last subchapter, we're in it
          foundSubchapterTitle = subchapter.chapter;
          print('✅ Found last subchapter: "${foundSubchapterTitle}" (page $pageInChapter >= ${subchapter.pageInChapter})');
        }
      }
    }

    print('🎯 Returning subchapter: "$foundSubchapterTitle"');
    return foundSubchapterTitle;
  }

  /// Update subchapter title based on current page position using actual pagination map
  /// This uses the _subchapterPageMapByChapter which contains actual paginated offsets
  String? updateSubchapterTitleForPageWithMap({
    required int currentChapterIndex,
    required int pageInChapter,
    required List<LocalChapterModel> chaptersList,
    Map<String, int>? subchapterPageMap,
  }) {
    if (subchapterPageMap == null || subchapterPageMap.isEmpty) {
      print('🔍 No subchapter map available for chapter $currentChapterIndex');
      return null;
    }

    print('🔍 updateSubchapterTitleForPageWithMap: chapterIdx=$currentChapterIndex, page=$pageInChapter');
    print('📋 Subchapter map: $subchapterPageMap');

    // Convert map to sorted list of entries
    final sortedEntries = subchapterPageMap.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    String? foundSubchapterTitle;

    // Find the subchapter we're currently in
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final subchapterTitle = entry.key;
      final subchapterStartPage = entry.value;

      // If we're at or after this subchapter's page
      if (pageInChapter >= subchapterStartPage) {
        // Check if there's a next subchapter
        if (i + 1 < sortedEntries.length) {
          final nextEntry = sortedEntries[i + 1];
          final nextStartPage = nextEntry.value;
          // If we haven't reached the next subchapter yet
          if (pageInChapter < nextStartPage) {
            foundSubchapterTitle = subchapterTitle;
            print('✅ Found subchapter: "$foundSubchapterTitle" (page $pageInChapter is between $subchapterStartPage and $nextStartPage)');
            break;
          }
        } else {
          // This is the last subchapter, we're in it
          foundSubchapterTitle = subchapterTitle;
          print('✅ Found last subchapter: "$foundSubchapterTitle" (page $pageInChapter >= $subchapterStartPage)');
        }
      }
    }

    print('🎯 Returning subchapter from map: "$foundSubchapterTitle"');
    return foundSubchapterTitle;
  }

  /// Get display title for chapter (including subchapter if active)
  String getChapterTitleForDisplay({
    required int currentChapterIndex,
    required List<LocalChapterModel> chaptersList,
    String? currentSubchapterTitle,
  }) {
    // If we have a subchapter title set, use it
    if (currentSubchapterTitle != null && currentSubchapterTitle.isNotEmpty) {
      return currentSubchapterTitle;
    }

    if (currentChapterIndex < 0 || currentChapterIndex >= chaptersList.length) {
      return '';
    }

    // Return the current chapter's title
    return chaptersList[currentChapterIndex].chapter;
  }

  /// Initialize EPUB book structure
  void initializeEpubStructure() {
    // Debug EPUB structure
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

    // Fix chapters for PDF-to-EPUB converted books
    EpubChapterFixer.fixChaptersIfNeeded(epubBook);
    log('📚 After fix - Total Chapters: ${epubBook.Chapters?.length ?? 0}');
  }

  /// Get book title from EPUB metadata
  String getBookTitle() {
    return epubBook.Title ?? 'Unknown Book';
  }
}
