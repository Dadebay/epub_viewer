import 'package:html/parser.dart' show parse;

/// Utilities for extracting chapter titles from EPUB HTML content
class EpubTitleExtractor {
  /// Extract meaningful chapter title from HTML content
  /// Tries multiple strategies to find the best title
  static String? extractTitleFromHtmlContent(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) return null;

    try {
      final document = parse(htmlContent);
      final bodyText = document.body?.text ?? '';

      // Strategy 1: Look for "CHAPTER X - Title" or "CHAPTER X: Title" patterns
      final chapterWithTitle = RegExp(
        r'CHAPTER\s+(\d+|[IVXLCDM]+)\s*[-–—:]\s*(.{3,80})',
        caseSensitive: false,
      ).firstMatch(bodyText);

      if (chapterWithTitle != null) {
        final chapterNum = chapterWithTitle.group(1);
        final chapterTitle = chapterWithTitle.group(2)?.trim();
        if (chapterNum != null && chapterTitle != null && chapterTitle.isNotEmpty) {
          final title = 'CHAPTER $chapterNum - $chapterTitle';
          if (!_isGenericTitle(title) && title.length > 10 && title.length < 100) {
            return title;
          }
        }
      }

      // Strategy 2: Look for standalone "CHAPTER X" (without subtitle)
      final chapterOnly = RegExp(
        r'CHAPTER\s+(\d+|[IVXLCDM]+)',
        caseSensitive: false,
      ).firstMatch(bodyText);

      if (chapterOnly != null) {
        final chapterNum = chapterOnly.group(1);
        if (chapterNum != null) {
          // Validate if it's a Roman numeral
          final isRoman = _isValidRomanNumeral(chapterNum);
          if (isRoman || int.tryParse(chapterNum) != null) {
            final title = 'CHAPTER $chapterNum';
            return title;
          }
        }
      }

      // Strategy 3: Look for heading tags (h1, h2)
      final h1 = document.querySelector('h1');
      if (h1 != null) {
        final title = _cleanHtmlTitle(h1.text);
        if (title.isNotEmpty && !_isGenericTitle(title) && title.length > 3) {
          return title;
        }
      }

      final h2 = document.querySelector('h2');
      if (h2 != null) {
        final title = _cleanHtmlTitle(h2.text);
        if (title.isNotEmpty && !_isGenericTitle(title) && title.length > 3) {
          return title;
        }
      }

      // Strategy 4: Look for <p class="chapter"> or similar
      final chapterPara = document.querySelector('p[class*="chapter"]');
      if (chapterPara != null) {
        final title = _cleanHtmlTitle(chapterPara.text);
        if (title.isNotEmpty && !_isGenericTitle(title) && title.length > 3) {
          return title;
        }
      }

      // Strategy 5: Look for first bold/strong text
      final firstBold = document.querySelector('b, strong');
      if (firstBold != null) {
        final text = firstBold.text.trim();
        if (text.length >= 5 && text.length <= 100) {
          final containsChapter = text.toLowerCase().contains('chapter');
          if (containsChapter && !_isGenericTitle(text)) {
            return text;
          }
        }
      }

      // Strategy 6: Look for h3 tags
      final h3 = document.querySelector('h3');
      if (h3 != null) {
        final match = RegExp(r'CHAPTER\s+\d+', caseSensitive: false).firstMatch(h3.text);
        if (match != null) {
          final title = _cleanHtmlTitle(match.group(0) ?? '');
          if (title.isNotEmpty && !_isGenericTitle(title) && title.length > 3) {
            return title;
          }
        }
      }
    } catch (e) {}

    return null;
  }

  /// Check if string is a valid Roman numeral
  static bool _isValidRomanNumeral(String s) {
    if (s.isEmpty) return false;
    return RegExp(r'^M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$').hasMatch(s);
  }

  /// Clean HTML title by removing tags and extra whitespace
  static String _cleanHtmlTitle(String title) {
    return title.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Check if title is too generic/useless
  static bool _isGenericTitle(String title) {
    final lower = title.toLowerCase();
    return lower == 'index' || lower == 'titlepage' || lower == 'title page' || lower == 'cover' || lower.contains('split') || lower.contains('.html') || lower.contains('.xhtml');
  }
}
