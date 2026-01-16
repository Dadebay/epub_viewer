import 'package:epubx/epubx.dart';

/// Utilities for fixing and creating chapters in EPUBs with broken structure
class EpubChapterFixer {
  /// Fix for EPUBs where navigation is broken but HTML files exist
  /// Handles PDF-to-EPUB conversions and malformed EPUBs
  static void fixChaptersIfNeeded(EpubBook epubBook) {
    try {
      final chapters = epubBook.Chapters ?? [];
      final htmlFiles = epubBook.Content?.Html ?? {};
      final images = epubBook.Content?.Images ?? {};
      final spine = epubBook.Schema?.Package?.Spine?.Items ?? [];

      // Validate basic EPUB structure
      if (htmlFiles.isEmpty && images.isEmpty) {
        _createDummyChapter(epubBook);
        return;
      }

      // ✅ IMPORTANT: Don't fix if EPUB already has good chapter structure
      // If chapters count is reasonable compared to HTML files, EPUB is probably fine
      if (chapters.length >= htmlFiles.length / 2 && chapters.length > 5) {
        if (_hasInvalidChapters(chapters)) {
          _repairChapterContent(epubBook);
        }
        return;
      }

      // Fix 1: If we have 1 or fewer chapters but multiple content files
      if (chapters.length <= 1 && (htmlFiles.length > 1 || (htmlFiles.isEmpty && images.length > 1))) {
        // Check if existing chapter is valid before replacing
        // But don't keep it if it's just a titlepage/cover or too short
        bool hasValidExistingChapter = false;
        if (chapters.isNotEmpty && chapters[0].HtmlContent != null && chapters[0].HtmlContent!.isNotEmpty) {
          final fileName = chapters[0].ContentFileName?.toLowerCase() ?? '';
          final chapterTitle = chapters[0].Title?.toLowerCase() ?? '';
          final contentLength = chapters[0].HtmlContent!.length;

          // Don't consider titlepage/cover as valid chapter
          final isTitleOrCover = fileName.contains('titlepage') || fileName.contains('cover') || chapterTitle.contains('titlepage') || chapterTitle.contains('cover') || chapterTitle == 'start';

          // Don't consider too-short content as valid (less than 1KB probably just metadata)
          final isTooShort = contentLength < 1000;

          hasValidExistingChapter = !isTitleOrCover && !isTooShort;
        }

        if (hasValidExistingChapter) {
          return;
        }

        final newChapters = <EpubChapter>[];

        // Try spine order first, then fallback to sorted HTML files
        if (spine.isNotEmpty) {
          _createChaptersFromSpine(epubBook, spine, htmlFiles, newChapters);
        }

        if (newChapters.isEmpty && htmlFiles.isNotEmpty) {
          _createChaptersFromHtmlFiles(htmlFiles, newChapters);
        }

        if (newChapters.isNotEmpty) {
          epubBook.Chapters = newChapters;
        } else {
          // If all chapters were skipped (metadata pages), don't replace original chapters
          // This preserves the working EPUB structure even if we couldn't improve it
        }
      }

      // Fix 2: Validate existing chapters have content
      if (chapters.isNotEmpty && _hasInvalidChapters(chapters)) {
        _repairChapterContent(epubBook);
      }
    } catch (e, st) {}
  }

  static void _createDummyChapter(EpubBook epubBook) {
    final dummyChapter = EpubChapter();
    dummyChapter.Title = 'Empty Book';
    dummyChapter.HtmlContent = '<html><body><p>This EPUB file appears to be empty or corrupted.</p></body></html>';
    dummyChapter.SubChapters = [];
    epubBook.Chapters = [dummyChapter];
  }

  static void _createChaptersFromSpine(
    EpubBook epubBook,
    List<EpubSpineItemRef> spine,
    Map<String, EpubTextContentFile> htmlFiles,
    List<EpubChapter> newChapters,
  ) {
    int index = 0;
    final List<(String href, String title, String content)> indexSplitFiles = [];
    final List<String> splitChapterTitles = [];

    // First pass: collect split chapter titles and index_split files
    for (var spineItem in spine) {
      final idRef = spineItem.IdRef;
      if (idRef == null) continue;

      final manifestItems = epubBook.Schema?.Package?.Manifest?.Items;
      if (manifestItems == null) continue;

      EpubManifestItem? manifestItem;
      try {
        manifestItem = manifestItems.firstWhere((m) => m.Id == idRef);
      } catch (e) {
        continue;
      }

      if (manifestItem.Href == null) continue;

      final href = manifestItem.Href!;
      final isHtml = href.endsWith('.html') || href.endsWith('.xhtml') || href.endsWith('.htm');

      if (!isHtml) continue;

      final htmlContent = htmlFiles[href];
      if (htmlContent == null) continue;

      final fallbackTitle = _extractChapterTitle(href, index);

      // Check if this is index_split file
      final isIndexSplit = href.toLowerCase().contains('index_split') || fallbackTitle.toLowerCase().contains('index split');

      if (isIndexSplit) {
        indexSplitFiles.add((href, fallbackTitle, htmlContent.Content ?? ''));

        // Special: Extract chapter titles from index_split_000 (first file with titles)
        if (href.toLowerCase().contains('index_split_000') || href.toLowerCase().contains('index_split_0')) {
          final splitChapters = _splitHtmlByChapters(htmlContent.Content ?? '', fallbackTitle);
          for (var (chapterTitle, _) in splitChapters) {
            // Skip if just number without description (duplicates)
            final isJustNumber = RegExp(r'^[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+$').hasMatch(chapterTitle);
            if (!isJustNumber && chapterTitle != fallbackTitle && !chapterTitle.toLowerCase().contains('index split')) {
              splitChapterTitles.add(chapterTitle);
            }
          }
        }
        continue;
      }

      // Skip titlepage/cover
      if (htmlFiles.length > 2 && _shouldSkipChapter(fallbackTitle, href)) {
        continue;
      }

      // Extract chapter titles from split
      final splitChapters = _splitHtmlByChapters(htmlContent.Content, fallbackTitle);
      for (var (chapterTitle, _) in splitChapters) {
        // Skip if just number without description (duplicates)
        final isJustNumber = RegExp(r'^[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+$').hasMatch(chapterTitle);
        if (!isJustNumber && chapterTitle != fallbackTitle) {
          splitChapterTitles.add(chapterTitle);
        }
      }
    }

    // Second pass: Create chapters from collected titles
    if (splitChapterTitles.isNotEmpty && indexSplitFiles.isNotEmpty) {
      // Calculate how many chapters each file should have
      final totalTitles = splitChapterTitles.length;
      final totalFiles = indexSplitFiles.length;
      final baseChaptersPerFile = totalTitles ~/ totalFiles;
      final extraChapters = totalTitles % totalFiles;

      int titleIndex = 0;
      int fileIndex = 0;

      for (var (href, _, content) in indexSplitFiles) {
        // How many chapters for this file?
        final chaptersForThisFile = fileIndex < extraChapters ? baseChaptersPerFile + 1 : baseChaptersPerFile;

        for (int i = 0; i < chaptersForThisFile && titleIndex < totalTitles; i++) {
          final chapterTitle = splitChapterTitles[titleIndex];

          final chapter = EpubChapter();
          chapter.Title = chapterTitle;
          chapter.HtmlContent = content; // Use FULL file content
          chapter.ContentFileName = href;
          chapter.Anchor = '$href#${chapterTitle.replaceAll(' ', '_')}';
          chapter.SubChapters = [];

          newChapters.add(chapter);
          index++;
          titleIndex++;
        }
        fileIndex++;
      }
    } else if (indexSplitFiles.isNotEmpty) {
      // Fallback: No titles collected, use file names
      for (var (href, fallbackTitle, content) in indexSplitFiles) {
        final chapter = EpubChapter();
        chapter.Title = fallbackTitle;
        chapter.HtmlContent = content;
        chapter.ContentFileName = href;
        chapter.Anchor = href;
        chapter.SubChapters = [];

        newChapters.add(chapter);
        index++;
      }
    }
  }

  static void _createChaptersFromHtmlFiles(
    Map<String, EpubTextContentFile> htmlFiles,
    List<EpubChapter> newChapters,
  ) {
    final sortedHtmlKeys = htmlFiles.keys.toList()..sort();
    int index = 0;
    final List<(String key, String title, String content)> indexSplitFiles = [];

    // First pass: process non-index_split files
    for (var htmlKey in sortedHtmlKeys) {
      final htmlContent = htmlFiles[htmlKey];
      if (htmlContent == null) continue;

      final fallbackTitle = _extractChapterTitle(htmlKey, index);

      // Check if this is index_split file - store for later use only if needed
      final isIndexSplit = htmlKey.toLowerCase().contains('index_split') || fallbackTitle.toLowerCase().contains('index split');

      if (isIndexSplit) {
        indexSplitFiles.add((htmlKey, fallbackTitle, htmlContent.Content ?? ''));
        continue;
      }

      // Skip titlepage/cover BEFORE splitting (for books with many chapters)
      // But process it if this is the only HTML file (broken EPUBs)
      if (htmlFiles.length > 2 && _shouldSkipChapter(fallbackTitle, htmlKey)) {
        continue;
      }

      final splitChapters = _splitHtmlByChapters(htmlContent.Content, fallbackTitle);

      // If split returned only the fallback (no actual split happened), skip this file
      // This prevents adding "index split 001" etc as chapters when they have no content
      if (splitChapters.length == 1 && splitChapters[0].$1 == fallbackTitle) {
        // Check if this looks like index_split file with no content
        if (fallbackTitle.toLowerCase().contains('index split') || fallbackTitle.toLowerCase().contains('index_split')) {
          continue;
        }
      }

      for (var (chapterTitle, chapterContent) in splitChapters) {
        final chapter = EpubChapter();
        chapter.Title = chapterTitle;
        chapter.HtmlContent = chapterContent;
        chapter.ContentFileName = htmlKey;
        chapter.Anchor = '$htmlKey#${chapterTitle.replaceAll(' ', '_')}';
        chapter.SubChapters = [];

        newChapters.add(chapter);
        index++;
      }
    }

    // Second pass: if no chapters found, use index_split files (for broken EPUBs)
    if (newChapters.isEmpty && indexSplitFiles.isNotEmpty) {
      index = 0;
      for (var (key, title, content) in indexSplitFiles) {
        final splitChapters = _splitHtmlByChapters(content, title);

        for (var (chapterTitle, chapterContent) in splitChapters) {
          final chapter = EpubChapter();
          chapter.Title = chapterTitle;
          chapter.HtmlContent = chapterContent;
          chapter.ContentFileName = key;
          chapter.Anchor = '$key#${chapterTitle.replaceAll(' ', '_')}';
          chapter.SubChapters = [];

          newChapters.add(chapter);
          index++;
        }
      }
    }
  }

  static bool _hasInvalidChapters(List<EpubChapter> chapters) {
    for (var chapter in chapters) {
      if (chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
        return true;
      }
    }
    return false;
  }

  static void _repairChapterContent(EpubBook epubBook) {
    final htmlFiles = epubBook.Content?.Html ?? {};

    for (var chapter in epubBook.Chapters ?? []) {
      if (chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
        if (chapter.ContentFileName != null) {
          final content = htmlFiles[chapter.ContentFileName!];
          if (content != null) {
            chapter.HtmlContent = content.Content;
          }
        }
      }
    }
  }

  static void createFallbackChapter(
    EpubBook epubBook,
    Map<String, EpubTextContentFile> htmlFiles,
    Map<String, EpubByteContentFile> images,
  ) {
    if (htmlFiles.isNotEmpty) {
      final combinedHtml = StringBuffer('<html><body>');
      final sortedKeys = htmlFiles.keys.toList()..sort();

      for (var key in sortedKeys) {
        final content = htmlFiles[key]?.Content ?? '';
        combinedHtml.write('<div>');
        combinedHtml.write(content);
        combinedHtml.write('</div>');
      }

      combinedHtml.write('</body></html>');

      final chapter = EpubChapter();
      chapter.Title = 'Book Content';
      chapter.HtmlContent = combinedHtml.toString();
      chapter.SubChapters = [];

      epubBook.Chapters = [chapter];
    }
  }

  /// Check if a chapter should be skipped (non-content pages)
  static bool _shouldSkipChapter(String title, String filename) {
    final lowerTitle = title.toLowerCase();
    final lowerFilename = filename.toLowerCase();

    // Skip common non-content pages
    // NOTE: "index_split" removed - these are actual content files in PDF-to-EPUB conversions
    final skipPatterns = [
      'titlepage',
      'title page',
      'title_page',
      'cover',
      'toc',
      'table of contents',
      'copyright',
      'nav',
    ];

    for (var pattern in skipPatterns) {
      if (lowerTitle.contains(pattern) || lowerFilename.contains(pattern)) {
        return true;
      }
    }

    return false;
  }

  static String _extractChapterTitle(String filename, int index) {
    String title = filename.split('/').last.replaceAll('.html', '').replaceAll('.xhtml', '').replaceAll('.htm', '').replaceAll('_', ' ').trim();

    if (title.contains('-')) {
      final parts = title.split('-');
      if (parts.length > 1 && parts[0].length <= 4) {
        title = parts.sublist(1).join('-').trim();
      }
    }

    if (title.isEmpty || title.length < 2) {
      return 'Chapter ${index + 1}';
    }

    return title.length > 50 ? 'Chapter ${index + 1}' : title;
  }

  static List<(String title, String content)> _splitHtmlByChapters(
    String? htmlContent,
    String fallbackTitle,
  ) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return [(fallbackTitle, htmlContent ?? '')];
    }

    try {
      final bodyMatch = RegExp(
        r'<body[^>]*>(.*?)</body>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(htmlContent);
      final bodyContent = bodyMatch?.group(1) ?? htmlContent;

      final plainTextPattern = RegExp(
        r'(?:^|\n)\s*([Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+(?:\s*[-–—:]\s*[^\n]{1,100})?)\s*(?:\n|$)',
        multiLine: true,
      );

      final plainText = bodyContent.replaceAll(RegExp(r'<[^>]+>'), '\n');
      final allMatches = plainTextPattern.allMatches(plainText).toList();

      final chapterMatches = allMatches.where((match) {
        final title = match.group(1)?.trim() ?? '';
        return title.startsWith('C') && !title.contains(';') && !title.contains(',') && !title.toLowerCase().contains('when ') && !title.toLowerCase().contains('where ') && title.length >= 9;
      }).toList();

      if (chapterMatches.length <= 1) {
        // No split found - return fallback as single chapter
        // The caller will check if this should be skipped (metadata)
        return [(fallbackTitle, htmlContent)];
      }

      final chapters = <(String title, String content)>[];

      for (int i = 0; i < chapterMatches.length; i++) {
        final match = chapterMatches[i];
        final chapterTitle = match.group(1)?.trim() ?? 'Chapter ${i + 1}';

        // Skip chapters that are just numbers without description (duplicates)
        // Example: "CHAPTER 1" or "Chapter 1" without " - description"
        final isJustNumber = RegExp(r'^[Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+$').hasMatch(chapterTitle);
        if (isJustNumber) {
          continue;
        }

        final searchText = chapterTitle.substring(0, chapterTitle.length.clamp(0, 20));
        final startIndex = htmlContent.indexOf(searchText);

        if (startIndex == -1) continue;

        int endIndex;
        if (i < chapterMatches.length - 1) {
          final nextMatch = chapterMatches[i + 1];
          final nextSearchText = (nextMatch.group(1) ?? '').trim().substring(0, (nextMatch.group(1) ?? '').trim().length.clamp(0, 20));
          endIndex = htmlContent.indexOf(nextSearchText, startIndex + searchText.length);
          if (endIndex == -1) endIndex = htmlContent.length;
        } else {
          endIndex = htmlContent.length;
        }

        final chapterContent = htmlContent.substring(startIndex, endIndex);
        final wrappedContent = '''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body>$chapterContent</body>
</html>''';

        chapters.add((chapterTitle, wrappedContent));
      }

      if (chapters.isEmpty) {
        return [(fallbackTitle, htmlContent)];
      }

      return chapters;
    } catch (e) {
      return [(fallbackTitle, htmlContent)];
    }
  }
}
