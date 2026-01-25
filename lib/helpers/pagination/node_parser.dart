import 'package:cosmos_epub/helpers/pagination/html_parsing_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html/dom.dart' as dom;

/// Parses HTML nodes into Flutter InlineSpans
class NodeParser {
  final TextStyle contentStyle;
  final bool isFrontMatter;
  final String chapterTitle;
  final List<String> subchapterTitles;
  final Future<InlineSpan> Function(dom.Element node, double maxWidth) onImageNode;

  NodeParser({
    required this.contentStyle,
    required this.isFrontMatter,
    required this.chapterTitle,
    required this.subchapterTitles,
    required this.onImageNode,
  }) {
    print('📖 NodeParser initialized:');
    print('   Chapter Title: "$chapterTitle"');
    print('   Subchapter Titles: ${subchapterTitles.map((t) => '"$t"').join(', ')}');
  }

  Future<InlineSpan> parseNode(dom.Node node, double maxWidth, {bool isPoetry = false}) async {
    if (node is dom.Text) {
      return _parseTextNode(node, isPoetry);
    } else if (node is dom.Element) {
      return _parseElementNode(node, maxWidth, isPoetry);
    }
    return const TextSpan(text: "");
  }

  TextSpan _parseTextNode(dom.Text node, bool isPoetry) {
    String text = node.text;

    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\u200B', '');
    text = text.replaceAll('\u2009', ' ');
    text = text.replaceAll('\u202F', ' ');

    if (!isPoetry) {
      text = text.replaceAll(RegExp(r'\s+'), ' ');
      text = text.replaceAllMapped(
        RegExp(r'([\.,;:!?])([A-Za-z\u0400-\u04FF])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
    }

    if (text.trim().isEmpty) {
      return const TextSpan(text: '');
    }

    text = text.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), r'$1');
    text = text.replaceAll(RegExp(r'([([«])\s+'), r'$1');

    return TextSpan(
      text: text,
      style: contentStyle.copyWith(
        color: contentStyle.color,
        fontFamily: 'SFPro',
        height: isFrontMatter ? 1.25 : 1.5,
        letterSpacing: isFrontMatter ? 0.0 : 0.1,
        wordSpacing: isFrontMatter ? 0.0 : 0.5,
        overflow: TextOverflow.visible,
      ),
    );
  }

  Future<InlineSpan> _parseElementNode(dom.Element node, double maxWidth, bool isPoetry) async {
    final nodeText = node.text.trim();

    // DEBUG: Tüm kısa metinleri logla
    if (nodeText.isNotEmpty && nodeText.length < 50 && !nodeText.contains('\n')) {
      print('📌 ELEMENT: <${node.localName}> içerik: "$nodeText"');
    }

    switch (node.localName) {
      case 'img':
        return onImageNode(node, maxWidth);
      case 'br':
        return const TextSpan(text: "\n");
      case 'p':
      case 'div':
        return _parseParagraphOrDiv(node, maxWidth);
      case 'h1':
      case 'h2':
      case 'h3':
        return _parseHeading(node, maxWidth);
      case 'blockquote':
        return _parseBlockquote(node, maxWidth);
      case 'cite':
        return _parseCite(node, maxWidth);
      case 'em':
      case 'i':
        return _parseItalic(node, maxWidth, isPoetry);
      case 'strong':
      case 'b':
        return _parseBold(node, maxWidth, isPoetry);
      default:
        return _parseGenericElement(node, maxWidth, isPoetry);
    }
  }

  Future<InlineSpan> _parseParagraphOrDiv(dom.Element node, double maxWidth) async {
    final paragraphText = node.text.trim();
    final isShortText = paragraphText.isNotEmpty && paragraphText.length < 80;
    final hasNoLineBreaks = !paragraphText.contains('\n');
    final normalizedParagraph = HtmlParsingHelpers.normalizeTitle(paragraphText);

    // ========== BASIT VE AGRESIF EŞLEŞME ==========
    // Tüm başlıkları küçük harfe çevir ve karşılaştır
    final allTitles = [chapterTitle, ...subchapterTitles];
    final paragraphLower = paragraphText.toLowerCase().trim();

    bool isDirectTitleMatch = false;
    String? matchedTitle;

    // Paragraf herhangi bir başlığın parçası mı kontrol et
    for (final title in allTitles) {
      final titleLower = title.toLowerCase().trim();
      if (titleLower.isEmpty) continue;

      // Tam eşleşme
      if (paragraphLower == titleLower) {
        isDirectTitleMatch = true;
        matchedTitle = title;
        break;
      }

      // Paragraf başlığın içinde mi? (örn: "Часть I" -> "Часть I Проблемы" içinde)
      if (titleLower.contains(paragraphLower) && paragraphLower.length >= 4) {
        isDirectTitleMatch = true;
        matchedTitle = title;
        break;
      }

      // Başlık paragrafın içinde mi?
      if (paragraphLower.contains(titleLower) && titleLower.length >= 4) {
        isDirectTitleMatch = true;
        matchedTitle = title;
        break;
      }
    }

    if (isDirectTitleMatch && isShortText && hasNoLineBreaks) {
      print('🎯 DİREKT EŞLEŞME: "$paragraphText" <-> "$matchedTitle"');
    }
    // ========== BASIT VE AGRESIF EŞLEŞME SONU ==========

    final isSubchapterTitle = isShortText && hasNoLineBreaks && (HtmlParsingHelpers.isSubchapterTitle(paragraphText, subchapterTitles) || _matchesAnyTitle(normalizedParagraph, subchapterTitles));

    final chapterTitleText = chapterTitle.trim();
    final normalizedChapterTitle = HtmlParsingHelpers.normalizeTitle(chapterTitleText);
    final isChapterTitle = isShortText &&
        hasNoLineBreaks &&
        normalizedParagraph.isNotEmpty &&
        normalizedChapterTitle.isNotEmpty &&
        (normalizedParagraph == normalizedChapterTitle || _matchesSingleTitle(normalizedParagraph, normalizedChapterTitle));

    // AGGRESSIVE MATCHING: Check if paragraph is part of ANY title
    bool isPartialChapterTitle = false;
    bool isPartialSubchapterTitle = false;

    if (isShortText && hasNoLineBreaks && paragraphText.length >= 3) {
      // Check against chapter title
      isPartialChapterTitle = _isPartOfTitle(paragraphText, chapterTitle);

      // Check against ALL subchapter titles
      for (final title in subchapterTitles) {
        if (_isPartOfTitle(paragraphText, title)) {
          isPartialSubchapterTitle = true;
          break;
        }
      }
    }

    final hasBoldChild = node.children.any((child) =>
        child.localName == 'b' ||
        child.localName == 'strong' ||
        (child.localName == 'span' && (child.attributes['style']?.contains('font-weight') == true || child.attributes['style']?.contains('bold') == true)));
    final isOnlyBold = node.children.length == 1 && (node.children.first.localName == 'b' || node.children.first.localName == 'strong');

    final hasHeadingClass = _elementHasHeadingClass(node);
    final hasHeadingStyle = _elementHasHeadingStyle(node);
    final isHeuristicHeading = hasNoLineBreaks && (_isLikelyHeadingText(paragraphText) || _isStandaloneShortHeading(paragraphText) || hasHeadingClass || hasHeadingStyle);
    final canRenderAsHeading = hasNoLineBreaks && (isShortText || _isLikelyHeadingText(paragraphText) || hasHeadingClass || hasHeadingStyle);

    // isDirectTitleMatch'ı da koşula ekle
    if ((isDirectTitleMatch || isChapterTitle || isSubchapterTitle || isPartialChapterTitle || isPartialSubchapterTitle || hasBoldChild || isOnlyBold || isHeuristicHeading) && canRenderAsHeading) {
      final reasons = <String>[];
      if (isDirectTitleMatch) reasons.add('DIRECT-MATCH');
      if (isChapterTitle) reasons.add('chapter-title');
      if (isSubchapterTitle) reasons.add('subchapter-title');
      if (isPartialChapterTitle) reasons.add('partial-chapter');
      if (isPartialSubchapterTitle) reasons.add('partial-subchapter');
      if (hasBoldChild) reasons.add('bold-child');
      if (isOnlyBold) reasons.add('only-bold');
      if (isHeuristicHeading) reasons.add('heuristic');
      if (hasHeadingClass) reasons.add('class');
      if (hasHeadingStyle) reasons.add('style');

      print('✅ HEADING MATCH: "$paragraphText" -> ${reasons.join(', ')}');

      final headingStyle = contentStyle.copyWith(
        color: contentStyle.color,
        fontSize: (contentStyle.fontSize ?? 16) + 4,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.normal,
        fontFamily: 'SFPro',
        height: isFrontMatter ? 1.25 : 1.5,
      );

      return TextSpan(
        text: '\n$paragraphText\n',
        style: headingStyle,
      );
    }

    if (paragraphText.isNotEmpty && hasNoLineBreaks && paragraphText.length <= 120) {
      print('🔎 HEADING CANDIDATE (miss): "$paragraphText"');
    }

    final isPoetry = HtmlParsingHelpers.isPoeticElement(node);

    if (isPoetry) {
      return _parsePoetry(node, maxWidth);
    } else {
      final isSectionDivider = HtmlParsingHelpers.isSectionDividerText(paragraphText);

      if (isSectionDivider) {
        return _parseSectionDivider(paragraphText, maxWidth);
      }

      return _parseProse(node, maxWidth);
    }
  }

  InlineSpan _parsePoetry(dom.Element node, double maxWidth) {
    List<String> poetryLines = [];
    Set<String> addedLines = {};

    void extractPoetryLines(dom.Element element) {
      for (var child in element.children) {
        if (child.localName == 'div' || child.localName == 'p') {
          String lineText = child.text.trim();
          if (lineText.isNotEmpty && lineText.length < 100 && !addedLines.contains(lineText)) {
            poetryLines.add(lineText);
            addedLines.add(lineText);
          }
        } else if (child.localName == 'blockquote') {
          extractPoetryLines(child);
        }
      }
    }

    extractPoetryLines(node);

    if (poetryLines.isEmpty) {
      String poetryHtml = node.innerHtml;
      poetryHtml = poetryHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      poetryHtml = poetryHtml.replaceAll(RegExp(r'<[^>]+>'), '');
      poetryHtml = poetryHtml.replaceAll('&nbsp;', ' ');
      poetryLines = poetryHtml.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    }

    String poetryText = poetryLines.join('\n');
    final centerPoetry = HtmlParsingHelpers.shouldCenterPoetry(poetryLines);

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        width: maxWidth,
        padding: EdgeInsets.only(bottom: isFrontMatter ? 4.h : 6.h, top: isFrontMatter ? 2.h : 4.h),
        child: Text(
          poetryText,
          textAlign: centerPoetry ? TextAlign.center : TextAlign.left,
          style: contentStyle.copyWith(
            color: contentStyle.color,
            fontFamily: 'SFPro',
            height: isFrontMatter ? 1.3 : 1.4,
            letterSpacing: isFrontMatter ? 0.0 : 0.1,
            wordSpacing: isFrontMatter ? 0.0 : 0.5,
          ),
        ),
      ),
    );
  }

  InlineSpan _parseSectionDivider(String text, double maxWidth) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        width: maxWidth,
        padding: EdgeInsets.symmetric(vertical: isFrontMatter ? 4.h : 8.h),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: contentStyle.copyWith(
            color: contentStyle.color,
            fontFamily: 'SFPro',
            height: isFrontMatter ? 1.25 : 1.5,
          ),
        ),
      ),
    );
  }

  Future<InlineSpan> _parseProse(dom.Element node, double maxWidth) async {
    List<InlineSpan> children = [];

    if (!isFrontMatter) {
      children.add(TextSpan(
        text: '\u00A0\u00A0\u00A0\u00A0\u00A0',
        style: contentStyle,
      ));
    }

    for (var child in node.nodes) {
      final span = await parseNode(child, maxWidth, isPoetry: false);
      children.add(span);
    }

    children.add(const TextSpan(text: '\n'));

    return TextSpan(children: children);
  }

  Future<InlineSpan> _parseHeading(dom.Element node, double maxWidth) async {
    final headingText = node.text.trim();

    print('✅ HEADING (h1/h2/h3): "$headingText" -> BOLD');

    // DİREKT text al, children parse etme - böylece bold style korunur
    return TextSpan(
      text: '\n$headingText\n',
      style: contentStyle.copyWith(
        color: contentStyle.color,
        fontSize: (contentStyle.fontSize ?? 16) + 4,
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.normal,
        fontFamily: 'SFPro',
        height: isFrontMatter ? 1.25 : 1.5,
      ),
    );
  }

  Future<InlineSpan> _parseBlockquote(dom.Element node, double maxWidth) async {
    String? authorName;

    for (var child in node.querySelectorAll('blockquote')) {
      var italicElement = child.querySelector('i') ?? child.querySelector('em');
      if (italicElement != null) {
        authorName = italicElement.text.trim();
        break;
      }
    }

    StringBuffer textBuffer = StringBuffer();
    void extractQuoteText(dom.Element element, {bool skipNestedBlockquote = false}) {
      for (var child in element.nodes) {
        if (child is dom.Element) {
          if (child.localName == 'blockquote' && skipNestedBlockquote) {
            continue;
          }
          extractQuoteText(child, skipNestedBlockquote: true);
        } else if (child is dom.Text) {
          textBuffer.write(child.text);
        }
      }
    }

    extractQuoteText(node, skipNestedBlockquote: true);
    String quoteText = textBuffer.toString().trim();

    if (quoteText.isEmpty) {
      return const TextSpan(text: '');
    }

    quoteText = _cleanText(quoteText);

    List<InlineSpan> spans = [];

    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: SizedBox(height: 20.h),
    ));

    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        width: maxWidth,
        alignment: Alignment.centerRight,
        margin: EdgeInsets.only(left: maxWidth / 4),
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Text(
          quoteText,
          textAlign: TextAlign.left,
          style: contentStyle.copyWith(
            color: contentStyle.color,
            fontStyle: FontStyle.normal,
            fontSize: (contentStyle.fontSize ?? 12) - 2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ));

    if (authorName != null && authorName.isNotEmpty) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          width: maxWidth,
          padding: EdgeInsets.only(top: 4.h, bottom: 8.h),
          child: Text(
            authorName,
            textAlign: TextAlign.center,
            style: contentStyle.copyWith(
              color: contentStyle.color,
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.bold,
              fontSize: (contentStyle.fontSize ?? 12) * 0.95,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ));
    } else {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: SizedBox(height: 8.h),
      ));
    }

    return TextSpan(children: spans);
  }

  InlineSpan _parseCite(dom.Element node, double maxWidth) {
    String authorText = '';
    for (var child in node.nodes) {
      if (child is dom.Text) {
        authorText += child.text;
      } else if (child is dom.Element) {
        authorText += child.text;
      }
    }

    authorText = authorText.trim();
    if (authorText.isEmpty) {
      return const TextSpan(text: '');
    }

    var prevSibling = node.previousElementSibling;
    if (prevSibling == null && node.parent != null) {
      prevSibling = node.parent!.previousElementSibling;
    }

    if (prevSibling != null && (prevSibling.localName == 'em' || prevSibling.localName == 'i') && prevSibling.text.trim().length > 80) {
      return const TextSpan(text: '');
    }

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        padding: EdgeInsets.fromLTRB(maxWidth / 2.5, 4.h, 0.w, 16.h),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            authorText,
            textAlign: TextAlign.right,
            style: contentStyle.copyWith(
              color: contentStyle.color,
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w600,
              height: isFrontMatter ? 1.2 : 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Future<InlineSpan> _parseItalic(dom.Element node, double maxWidth, bool isPoetry) async {
    List<InlineSpan> children = [];
    for (var child in node.nodes) {
      children.add(await parseNode(child, maxWidth, isPoetry: isPoetry));
    }

    final text = node.text.trim();
    final isLongQuote = text.length > 80;

    if (isLongQuote) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          width: maxWidth,
          padding: EdgeInsets.symmetric(
            vertical: isFrontMatter ? 6.h : 10.h,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: contentStyle.copyWith(
              color: contentStyle.color,
              fontStyle: FontStyle.normal,
              height: 1.4,
              fontSize: contentStyle.fontSize,
            ),
          ),
        ),
      );
    }

    return TextSpan(
      children: children,
      style: contentStyle.copyWith(
        color: contentStyle.color,
        fontStyle: FontStyle.normal,
      ),
    );
  }

  Future<InlineSpan> _parseBold(dom.Element node, double maxWidth, bool isPoetry) async {
    List<InlineSpan> children = [];
    for (var child in node.nodes) {
      children.add(await parseNode(child, maxWidth, isPoetry: isPoetry));
    }
    return TextSpan(
      children: children,
      style: contentStyle.copyWith(
        color: contentStyle.color,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<InlineSpan> _parseGenericElement(dom.Element node, double maxWidth, bool isPoetry) async {
    List<InlineSpan> children = [];
    for (var child in node.nodes) {
      children.add(await parseNode(child, maxWidth, isPoetry: isPoetry));
    }
    return TextSpan(children: children);
  }

  String _cleanText(String text) {
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\u200B', '');
    text = text.replaceAll('\u2009', ' ');
    text = text.replaceAll('\u202F', ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), r'$1');
    text = text.replaceAll(RegExp(r'([([«])\s+'), r'$1');
    return text.trim();
  }

  bool _matchesSingleTitle(String normalizedParagraph, String normalizedTitle) {
    if (normalizedParagraph.isEmpty || normalizedTitle.isEmpty) return false;

    if (normalizedParagraph == normalizedTitle) return true;

    if (normalizedParagraph.length > 5 && normalizedTitle.length > 5) {
      if (normalizedParagraph.startsWith(normalizedTitle) || normalizedParagraph.endsWith(normalizedTitle)) {
        return true;
      }
      if (normalizedParagraph.contains(normalizedTitle) || normalizedTitle.contains(normalizedParagraph)) {
        return true;
      }
    }

    return false;
  }

  /// Check if paragraph text is a significant part of a title
  /// This handles cases where titles are split across multiple HTML elements
  bool _isPartOfTitle(String paragraphText, String fullTitle) {
    if (paragraphText.isEmpty || fullTitle.isEmpty) return false;

    final normalizedParagraph = HtmlParsingHelpers.normalizeTitle(paragraphText);
    final normalizedTitle = HtmlParsingHelpers.normalizeTitle(fullTitle);

    // Skip if paragraph is too short to be meaningful
    if (normalizedParagraph.length < 2) return false;

    // Check if paragraph matches the full title
    if (normalizedParagraph == normalizedTitle) return true;

    // AGGRESSIVE: Split into words
    final paragraphWords = normalizedParagraph.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final titleWords = normalizedTitle.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (paragraphWords.isEmpty || titleWords.isEmpty) return false;

    // AGGRESSIVE: Check if paragraph forms a continuous sequence in title
    final titleText = titleWords.join(' ');
    final paragraphCombined = paragraphWords.join(' ');

    if (titleText.contains(paragraphCombined)) {
      print('   ✓ Continuous sequence match: "$paragraphCombined" in "$titleText"');
      return true;
    }

    // AGGRESSIVE: Check if all paragraph words exist in title (in order)
    int titleIndex = 0;
    int matchedWords = 0;

    for (final paragraphWord in paragraphWords) {
      for (int i = titleIndex; i < titleWords.length; i++) {
        if (titleWords[i] == paragraphWord || titleWords[i].contains(paragraphWord) || paragraphWord.contains(titleWords[i])) {
          matchedWords++;
          titleIndex = i + 1;
          break;
        }
      }
    }

    // If all paragraph words are found in title (in order), it's a match
    if (matchedWords == paragraphWords.length && paragraphWords.length >= 1) {
      print('   ✓ Sequential word match: $matchedWords/$matchedWords words matched');
      return true;
    }

    // AGGRESSIVE: For very short paragraphs (1-2 words), just check if words exist in title
    if (paragraphWords.length <= 2) {
      final allWordsExist = paragraphWords.every((word) => titleWords.any((titleWord) => titleWord == word || titleWord.contains(word) || word.contains(titleWord)));

      if (allWordsExist) {
        print('   ✓ All words exist in title: ${paragraphWords.join(" ")}');
        return true;
      }
    }

    return false;
  }

  bool _matchesAnyTitle(String normalizedParagraph, List<String> titles) {
    for (final title in titles) {
      final normalizedTitle = HtmlParsingHelpers.normalizeTitle(title);
      if (_matchesSingleTitle(normalizedParagraph, normalizedTitle)) {
        return true;
      }
    }
    return false;
  }

  bool _isLikelyHeadingText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final normalized = HtmlParsingHelpers.normalizeTitle(trimmed);
    if (normalized.isEmpty) return false;

    final lower = normalized.toLowerCase();

    final keywordMatch = RegExp(
          r'^(chapter|part|section|book|volume|vol|appendix|prologue|epilogue|giriş|sonuç|önsöz|sonsöz|bölüm|kısım|kisim|kitap|ek|эпилог|пролог|глава|часть|раздел)\b',
          caseSensitive: false,
        ).hasMatch(lower) ||
        RegExp(
          r'\b(chapter|part|section|book|volume|vol|appendix|prologue|epilogue|giriş|sonuç|önsöz|sonsöz|bölüm|kısım|kisim|kitap|ek|эпилог|пролог|глава|часть|раздел)\b',
          caseSensitive: false,
        ).hasMatch(lower);

    final hasRoman = RegExp(r'\b[ivxlcdm]+\b', caseSensitive: false).hasMatch(lower);
    final hasDigits = RegExp(r'\b\d+\b').hasMatch(lower);

    if (keywordMatch && (hasRoman || hasDigits)) {
      return true;
    }

    if (keywordMatch && normalized.length <= 30) {
      return true;
    }

    return false;
  }

  bool _isStandaloneShortHeading(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 6) return false;
    if (trimmed.length > 80) return false;

    if (RegExp(r'[\.,;:!?]$').hasMatch(trimmed)) return false;
    if (RegExp(r'[,;:]').hasMatch(trimmed)) return false;

    // Title-case or all-caps-ish (Cyrillic/Latin)
    final startsWithUpper = words.every((w) => RegExp(r'^[A-ZА-ЯЁ]').hasMatch(w));
    if (startsWithUpper) return true;

    // Single word headings like "Problemy" or "Предыстория"
    if (words.length == 1 && trimmed.length >= 4) return true;

    return false;
  }

  bool _elementHasHeadingClass(dom.Element element) {
    final className = element.className.toLowerCase();
    final idName = (element.attributes['id'] ?? '').toLowerCase();
    final dataType = (element.attributes['data-type'] ?? '').toLowerCase();
    final tokens = '$className $idName $dataType';

    return RegExp(
      r'\b(chapter|subchapter|section|part|title|heading|head|subtitle|toc|prologue|epilogue|эпилог|пролог|глава|часть|раздел|заголовок|подзаголовок)\b',
      caseSensitive: false,
    ).hasMatch(tokens);
  }

  bool _elementHasHeadingStyle(dom.Element element) {
    final style = (element.attributes['style'] ?? '').toLowerCase();
    if (style.isEmpty) return false;

    final hasBold = style.contains('font-weight') && (style.contains('bold') || RegExp(r'font-weight\s*:\s*[6-9]00').hasMatch(style));
    final hasLargeFont = RegExp(r'font-size\s*:\s*(1\.[2-9]em|[2-9]\d?px)').hasMatch(style);
    final isCentered = style.contains('text-align') && style.contains('center');

    return hasBold || hasLargeFont || isCentered;
  }
}
