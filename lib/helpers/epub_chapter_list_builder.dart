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

    return chapterTitle;
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
