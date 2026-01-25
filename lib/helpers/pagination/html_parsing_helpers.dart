import 'package:html/dom.dart' as dom;

/// Helper utilities for HTML content processing
class HtmlParsingHelpers {
  /// Extract text only from an element, optionally excluding cite tags
  static String extractTextOnly(dom.Element element, {bool excludeCite = false}) {
    StringBuffer buffer = StringBuffer();

    for (var child in element.nodes) {
      if (child is dom.Text) {
        buffer.write(child.text);
      } else if (child is dom.Element) {
        if (excludeCite && child.localName == 'cite') {
          continue;
        }
        buffer.write(extractTextOnly(child, excludeCite: excludeCite));
      }
    }

    return buffer.toString();
  }

  /// Check if text is a section divider (Roman numerals, "* * *", numbers, etc.)
  static bool isSectionDividerText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Must be reasonably short (section dividers are typically short)
    if (trimmed.length > 50) return false;

    // Common section divider patterns
    if (trimmed == '* * *' ||
        trimmed == '***' ||
        trimmed == '---' ||
        trimmed == '* * * *' ||
        trimmed == '----' ||
        trimmed == '————' ||
        trimmed == '• • •' ||
        trimmed == '...' ||
        RegExp(r'^[\*\-•\.—–\s]+$').hasMatch(trimmed)) {
      return true;
    }

    // Single Roman numeral
    if (RegExp(r'^[IVXLCDM]+\.?$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^\([IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^[IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Multiple Roman numerals separated by dots, spaces, or commas
    if (RegExp(r'^[IVXLCDM]+[\.\s,]+[IVXLCDM\.\s,]+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Arabic numerals as section dividers
    if (RegExp(r'^\d+\.?$').hasMatch(trimmed) || RegExp(r'^\(\d+\)$').hasMatch(trimmed) || RegExp(r'^\d+\)$').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Check if element contains poetry/verse
  static bool isPoeticElement(dom.Element element) {
    final brCount = element.querySelectorAll('br').length;
    final childDivCount = element.querySelectorAll('div, p').length;

    if (brCount >= 3 || childDivCount >= 3) {
      List<String> textSegments = [];

      void extractTextSegments(dom.Node node) {
        if (node is dom.Text) {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            textSegments.add(text);
          }
        } else if (node is dom.Element) {
          if (node.localName == 'br') return;
          if (node.localName == 'div' || node.localName == 'p') {
            final text = node.text.trim();
            if (text.isNotEmpty && text.length < 100) {
              textSegments.add(text);
            }
          }
          for (var child in node.nodes) {
            extractTextSegments(child);
          }
        }
      }

      for (var child in element.nodes) {
        extractTextSegments(child);
      }

      if (textSegments.length >= 3) {
        int shortSegments = 0;
        for (var i = 0; i < textSegments.length && i < 5; i++) {
          final seg = textSegments[i];
          final segLength = seg.length;
          if (segLength < 80 && segLength > 5) {
            shortSegments++;
          }
        }

        if (shortSegments >= (textSegments.take(5).length * 0.6).ceil()) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if poetry should be centered
  static bool shouldCenterPoetry(List<String> lines) {
    if (lines.isEmpty) return false;
    final lengths = lines.map((l) => l.trim().length).where((l) => l > 0).toList();
    if (lengths.isEmpty) return false;
    final maxLen = lengths.reduce((a, b) => a > b ? a : b);
    final avgLen = lengths.reduce((a, b) => a + b) / lengths.length;
    return avgLen <= 50 && maxLen <= 80;
  }

  /// Check if content looks like front matter (title page, copyright, etc.)
  static bool isFrontMatterContent(String rawText, String chapterTitle) {
    final cleaned = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return false;

    final lower = cleaned.toLowerCase();
    final titleLower = chapterTitle.trim().toLowerCase();

    final lengthOk = cleaned.length <= 2000;
    final shortLines = rawText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).length;

    final looksLikeFrontMatter = shortLines <= 14;
    final containsTitle = titleLower.isNotEmpty && lower.contains(titleLower);

    return lengthOk && looksLikeFrontMatter && containsTitle;
  }

  /// Normalize title for comparison
  static String normalizeTitle(String input) {
    return input.replaceAll('\u00AD', '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[\s\-–—:;.,!?«»"""]+|[\s\-–—:;.,!?«»"""]+$'), '').trim().toLowerCase();
  }

  /// Check if a paragraph is a subchapter title
  static bool isSubchapterTitle(String paragraphText, List<String> subchapterTitles) {
    final normalizedParagraph = normalizeTitle(paragraphText);
    if (normalizedParagraph.isEmpty) return false;

    for (var subTitle in subchapterTitles) {
      final normalizedSubTitle = normalizeTitle(subTitle);
      if (normalizedSubTitle.isNotEmpty) {
        // Exact match
        if (normalizedParagraph == normalizedSubTitle) {
          return true;
        }
        // Partial match for longer titles
        if (normalizedParagraph.length > 5 && normalizedSubTitle.length > 5) {
          if (normalizedParagraph.contains(normalizedSubTitle) || normalizedSubTitle.contains(normalizedParagraph)) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
