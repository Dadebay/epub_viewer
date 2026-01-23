import 'package:epubx/epubx.dart';

import '../models/chapter_model.dart';

/// Helper class for building chapters list from EPUB structure
class EpubChapterListBuilder {
  /// Build the chapters list from EPUB structure
  static Map<String, dynamic> buildChaptersList({
    required List<EpubChapter> chapters,
    required EpubBook epubBook,
    required Map<int, int> chapterPageCounts,
  }) {
    List<LocalChapterModel> chaptersList = [];
    Map<int, int> filteredToOriginalIndex = {};

    // Extract navigation titles
    Map<String, String> navTitles = _extractNavTitles(epubBook);

    for (int i = 0; i < chapters.length; i++) {
      var chapter = chapters[i];
      String? chapterTitle = _getChapterTitle(chapter, navTitles, i);

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

      // Add sub-chapters if available
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        _addSubChapters(
          chaptersList: chaptersList,
          filteredToOriginalIndex: filteredToOriginalIndex,
          subChapters: chapter.SubChapters!,
          parentChapterIndex: i,
          listIndex: listIndex,
          chapterStartPage: chapterStartPage,
          mainChapterPages: chapterPageCounts[i] ?? 0,
          chapterPageCounts: chapterPageCounts,
        );
      }
    }

    return {
      'chaptersList': chaptersList,
      'filteredToOriginalIndex': filteredToOriginalIndex,
    };
  }

  /// Extract navigation titles from EPUB
  static Map<String, String> _extractNavTitles(EpubBook epubBook) {
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
    return navTitles;
  }

  /// Get chapter title with fallback logic
  static String? _getChapterTitle(EpubChapter chapter, Map<String, String> navTitles, int index) {
    String? chapterTitle = chapter.Title;

    final needsExtraction = chapterTitle == null ||
        chapterTitle.isEmpty ||
        chapterTitle.contains('_split_') ||
        chapterTitle.toLowerCase().startsWith('index split') ||
        chapterTitle.toLowerCase().contains('index_split') ||
        chapterTitle.contains('.html') ||
        chapterTitle.contains('.xhtml') ||
        chapterTitle.toLowerCase() == 'titlepage' ||
        chapterTitle.toLowerCase() == 'index' ||
        chapterTitle.toLowerCase() == 'cover';

    final isBasicChapterTitle = chapterTitle != null && RegExp(r'^Chapter \d+$', caseSensitive: false).hasMatch(chapterTitle);

    if (needsExtraction || isBasicChapterTitle) {
      // First try navigation titles
      String? contentRef = chapter.ContentFileName;
      if (contentRef != null) {
        String fileName = contentRef.split('/').last.split('#').first;
        if (navTitles.containsKey(fileName)) {
          String navTitle = navTitles[fileName]!;
          if (navTitle.isNotEmpty && navTitle != chapterTitle && navTitle.toLowerCase() != 'start') {
            chapterTitle = navTitle;
            return chapterTitle;
          }
        }
      }

      // If still bad, try to extract from HTML content
      final htmlContent = chapter.HtmlContent ?? '';
      if (htmlContent.isNotEmpty) {
        final extractedTitle = _extractTitleFromHtml(htmlContent, index);
        if (extractedTitle != null && extractedTitle.isNotEmpty) {
          chapterTitle = extractedTitle;
        }
      }
    }

    return chapterTitle;
  }

  /// Extract title from HTML content
  static String? _extractTitleFromHtml(String htmlContent, int chapterIndex) {
    // Method 1: Look for <title> tag
    final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(htmlContent);
    if (titleMatch != null) {
      final title = titleMatch.group(1)?.trim() ?? '';
      if (_isValidTitle(title)) {
        return title;
      }
    }

    // Method 2: Look for h1 tag (with possible nested elements)
    final h1Match = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true).firstMatch(htmlContent);
    if (h1Match != null) {
      final rawTitle = h1Match.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (_isValidTitle(rawTitle) && rawTitle.length <= 100) {
        return rawTitle;
      }
    }

    // Method 3: Look for h2 tag
    final h2Match = RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false, dotAll: true).firstMatch(htmlContent);
    if (h2Match != null) {
      final rawTitle = h2Match.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (_isValidTitle(rawTitle) && rawTitle.length <= 100) {
        return rawTitle;
      }
    }

    // Method 4: Look for class="chapter" or class="title" elements
    final classMatch = RegExp(r'<[^>]+class="[^"]*(?:chapter|title|heading|baslik)[^"]*"[^>]*>(.*?)</', caseSensitive: false, dotAll: true).firstMatch(htmlContent);
    if (classMatch != null) {
      final rawTitle = classMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (_isValidTitle(rawTitle) && rawTitle.length <= 100) {
        return rawTitle;
      }
    }

    // Method 5: Look for "CHAPTER X" or "Chapter X: Title" pattern in text
    final plainText = htmlContent.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final chapterPattern = RegExp(
      r'(?:CHAPTER|Chapter|BÖLÜM|Bölüm|ГЛАВА|Глава|FASIL|Fasıl|BAB|Bab)\s+(\d+|[IVXLC]+)(?:\s*[-–—:．.]\s*(.{1,80}))?',
      caseSensitive: false,
    );

    final chapterMatch = chapterPattern.firstMatch(plainText);
    if (chapterMatch != null) {
      final num = chapterMatch.group(1) ?? '';
      final subtitle = chapterMatch.group(2)?.trim() ?? '';

      if (subtitle.isNotEmpty && _isValidTitle(subtitle)) {
        return 'Chapter $num: $subtitle';
      } else if (num.isNotEmpty) {
        return 'Chapter $num';
      }
    }

    // Method 6: Look for first significant bold/strong text at the beginning
    final boldMatch = RegExp(r'<(?:b|strong)[^>]*>([^<]{3,80})</(?:b|strong)>', caseSensitive: false).firstMatch(htmlContent);
    if (boldMatch != null) {
      final title = boldMatch.group(1)?.trim() ?? '';
      if (_isValidTitle(title) && title.length >= 3 && title.length <= 80) {
        return title;
      }
    }

    // No valid title found, return generic
    return 'Bölüm ${chapterIndex + 1}';
  }

  /// Check if a title is valid (not generic/useless)
  static bool _isValidTitle(String title) {
    if (title.isEmpty || title.length < 2) return false;

    final lowerTitle = title.toLowerCase();

    // Bad patterns
    if (lowerTitle.contains('index_split') ||
        lowerTitle.contains('index split') ||
        lowerTitle.contains('.html') ||
        lowerTitle.contains('.xhtml') ||
        lowerTitle == 'titlepage' ||
        lowerTitle == 'cover' ||
        lowerTitle == 'index' ||
        lowerTitle == 'start' ||
        lowerTitle == 'untitled' ||
        RegExp(r'^(part|section)_?\d+$').hasMatch(lowerTitle)) {
      return false;
    }

    return true;
  }

  /// Add sub-chapters to the list
  static void _addSubChapters({
    required List<LocalChapterModel> chaptersList,
    required Map<int, int> filteredToOriginalIndex,
    required List<EpubChapter> subChapters,
    required int parentChapterIndex,
    required int listIndex,
    required int chapterStartPage,
    required int mainChapterPages,
    required Map<int, int> chapterPageCounts,
  }) {
    int subChapterCount = subChapters.length;

    for (int subIdx = 0; subIdx < subChapters.length; subIdx++) {
      var subChapter = subChapters[subIdx];
      String? subTitle = subChapter.Title;

      if (subTitle != null && subTitle.isNotEmpty) {
        final subChapterIndex = chaptersList.length;

        int subChapterStartPage = 0;
        int pageInChapter = 0;

        if (mainChapterPages > 0 && subChapterCount > 0) {
          int pagesPerSubChapter = mainChapterPages ~/ (subChapterCount + 1);
          pageInChapter = pagesPerSubChapter * (subIdx + 1);
          subChapterStartPage = chapterStartPage + pageInChapter;
          if (subChapterStartPage > chapterStartPage + mainChapterPages - 1) {
            subChapterStartPage = chapterStartPage + mainChapterPages - 1;
            pageInChapter = mainChapterPages - 1;
          }
        }

        chaptersList.add(LocalChapterModel(
          chapter: subTitle,
          isSubChapter: true,
          startPage: chapterPageCounts.containsKey(parentChapterIndex) ? subChapterStartPage : 0,
          pageCount: 0,
          parentChapterIndex: listIndex,
          pageInChapter: pageInChapter,
        ));

        filteredToOriginalIndex[subChapterIndex] = parentChapterIndex;
      }
    }
  }
}
