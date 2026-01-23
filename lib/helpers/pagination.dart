import 'dart:typed_data';

import 'package:cosmos_epub/helpers/selectable_text_with_addnote.dart';
import 'package:cosmos_epub/page_flip/page_flip_widget.dart';
import 'package:cosmos_epub/helpers/functions.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'dart:ui' as ui;

class PagingTextHandler extends GetxController {
  PagingTextHandler({required this.paginate, required this.bookId}) {
    currentPage = (_box.read<int>('currentPage_$bookId') ?? 0).obs;
    totalPages = (_box.read<int>('totalPages_$bookId') ?? 0).obs;

    ever(currentPage, (_) => _box.write('currentPage_$bookId', currentPage.value));
    ever(totalPages, (_) => _box.write('totalPages_$bookId', totalPages.value));
  }

  final String bookId;
  late final RxInt currentPage;
  final Function paginate;
  late final RxInt totalPages;

  final _box = GetStorage();
  GlobalKey<PageFlipWidgetState>? _pageFlipController;

  void setPageFlipController(GlobalKey<PageFlipWidgetState> controller) {
    _pageFlipController = controller;
  }

  Future<void> goToNextPage() async {
    final state = _pageFlipController?.currentState;
    if (state == null) {
      return;
    }

    final currentPageNum = state.pageNumber;
    final totalPages = state.pages.length;

    if (currentPageNum < totalPages - 1) {
      final targetPage = currentPageNum + 1;

      await state.goToPage(targetPage);

      state.widget.onPageFlip(targetPage);
    }
  }

  Future<void> goToPreviousPage() async {
    final state = _pageFlipController?.currentState;
    if (state == null) {
      return;
    }

    final currentPageNum = state.pageNumber;

    if (currentPageNum > 0) {
      final targetPage = currentPageNum - 1;

      await state.goToPage(targetPage);

      state.widget.onPageFlip(targetPage);
    }
  }

  Future<bool> goToPage(int pageIndex) async {
    final state = _pageFlipController?.currentState;
    if (state == null) {
      return false;
    }

    final totalPagesCount = state.pages.length;

    if (pageIndex >= 0 && pageIndex < totalPagesCount) {
      await state.goToPage(pageIndex);
      state.widget.onPageFlip(pageIndex);
      return true;
    } else {
      return false;
    }
  }
}

class PagingWidget extends StatefulWidget {
  const PagingWidget(
    this.textContent,
    this.innerHtmlContent, {
    super.key,
    this.style = const TextStyle(
      color: Colors.black,
      fontSize: 12,
    ),
    required this.handlerCallback,
    required this.onTextTap,
    required this.onPageFlip,
    required this.onLastPage,
    this.starterPageIndex = 0,
    required this.chapterTitle,
    required this.totalChapters,
    this.lastWidget,
    required this.bookId,
    this.showNavBar = true,
    this.linesPerPage = 30,
    this.epubBook,
  });

  final String bookId;
  final String chapterTitle;
  final EpubBook? epubBook;
  final Function handlerCallback;
  final String? innerHtmlContent;
  final Widget? lastWidget;
  final int linesPerPage;
  final Function(int, int) onLastPage;
  final Function(int, int) onPageFlip;
  final VoidCallback onTextTap;
  final bool showNavBar;
  final int starterPageIndex;
  final TextStyle style;
  final String textContent;
  final int totalChapters;

  @override
  _PagingWidgetState createState() => _PagingWidgetState();
}

class _PagingWidgetState extends State<PagingWidget> {
  List<Widget> pages = [];
  Future<void> paginateFuture = Future.value(true);

  int _currentPageIndex = 0;
  late PagingTextHandler _handler;
  late RenderBox _initializedRenderBox;
  final _pageController = GlobalKey<PageFlipWidgetState>();
  final _pageKey = GlobalKey();
  final List<TextSpan> _pageSpans = [];
  bool _isFrontMatter = false;
  late TextStyle _contentStyle;

  bool _spanHasRealContent(InlineSpan span) {
    if (span is WidgetSpan) return true;

    if (span is TextSpan) {
      final text = span.text ?? '';
      if (text.replaceAll(RegExp(r'\s+'), '').isNotEmpty) {
        return true;
      }
      if (span.children != null && span.children!.isNotEmpty) {
        for (final child in span.children!) {
          if (_spanHasRealContent(child)) return true;
        }
      }
    }

    return false;
  }

  @override
  void didUpdateWidget(covariant PagingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style.fontSize != oldWidget.style.fontSize ||
        widget.style.fontFamily != oldWidget.style.fontFamily ||
        widget.style.color != oldWidget.style.color ||
        widget.style.backgroundColor != oldWidget.style.backgroundColor ||
        widget.style.height != oldWidget.style.height ||
        widget.innerHtmlContent != oldWidget.innerHtmlContent ||
        widget.textContent != oldWidget.textContent) {
      rePaginate();
    }
  }

  @override
  void initState() {
    super.initState();
    _handler = PagingTextHandler(paginate: rePaginate, bookId: widget.bookId);
    _handler.setPageFlipController(_pageController);
    widget.handlerCallback(_handler);
    rePaginate();
  }

  rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final renderObject = context.findRenderObject();
      if (renderObject == null) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) rePaginate();
        });
        return;
      }

      setState(() {
        _initializedRenderBox = renderObject as RenderBox;
        paginateFuture = _paginate();
      });
    });
  }

  String extractTextOnly(dom.Element element, {bool excludeCite = false}) {
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
  bool _isSectionDividerText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Must be reasonably short (section dividers are typically short)
    // Increased limit for multiple Roman numerals like "XXXIX. XL. XLI"
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

    // Single Roman numeral (I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII, XXXVIII, etc.)
    if (RegExp(r'^[IVXLCDM]+\.?$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^\([IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^[IVXLCDM]+\)$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Multiple Roman numerals separated by dots, spaces, or commas
    // Examples: "XXXIX. XL. XLI", "I II III", "X, XI, XII"
    if (RegExp(r'^[IVXLCDM]+[\.\s,]+[IVXLCDM\.\s,]+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Arabic numerals as section dividers (1, 2, 3, etc. or 1., 2., 3., etc.)
    if (RegExp(r'^\d+\.?$').hasMatch(trimmed) || RegExp(r'^\(\d+\)$').hasMatch(trimmed) || RegExp(r'^\d+\)$').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Check if element contains poetry/verse
  /// Poetry characteristics:
  /// - Multiple <br> tags (line breaks) OR
  /// - Multiple child <div>/<p> elements with short text
  bool _isPoeticElement(dom.Element element) {
    // Count <br> tags
    final brCount = element.querySelectorAll('br').length;

    // Count child div/p elements (paragraph-like)
    final childDivCount = element.querySelectorAll('div, p').length;

    // If element has multiple line breaks OR multiple child divs, check for poetry
    if (brCount >= 3 || childDivCount >= 3) {
      // Extract text segments from child elements
      List<String> textSegments = [];

      void extractTextSegments(dom.Node node) {
        if (node is dom.Text) {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            textSegments.add(text);
          }
        } else if (node is dom.Element) {
          if (node.localName == 'br') {
            return;
          }
          // For div/p elements, get their direct text content
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
        // Check if most segments are short (typical poetry lines)
        int shortSegments = 0;
        for (var i = 0; i < textSegments.length && i < 5; i++) {
          final seg = textSegments[i];
          final segLength = seg.length;
          if (segLength < 80 && segLength > 5) {
            shortSegments++;
          }
        }

        // If at least 60% of segments are short, it's poetry
        if (shortSegments >= (textSegments.take(5).length * 0.6).ceil()) {
          return true;
        }
      }
    }

    return false;
  }

  bool _shouldCenterPoetry(List<String> lines) {
    if (lines.isEmpty) return false;
    final lengths = lines.map((l) => l.trim().length).where((l) => l > 0).toList();
    if (lengths.isEmpty) return false;
    final maxLen = lengths.reduce((a, b) => a > b ? a : b);
    final avgLen = lengths.reduce((a, b) => a + b) / lengths.length;
    return avgLen <= 50 && maxLen <= 80;
  }

  bool _isFrontMatterContent(String rawText, String chapterTitle) {
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

  TextStyle _resolveContentStyle() {
    if (!_isFrontMatter) return widget.style;

    final baseFontSize = widget.style.fontSize ?? 12;
    return widget.style.copyWith(
      fontSize: baseFontSize * 0.9,
      height: 1.2,
      letterSpacing: 0.0,
      wordSpacing: 0.0,
    );
  }

  Future<void> _paginate() async {
    final pageSize = _initializedRenderBox.size;
    _pageSpans.clear();

    String contentToParse = widget.innerHtmlContent ?? widget.textContent;

    if (contentToParse.isEmpty) {
      throw Exception('No content available to display. Content is empty.');
    }

    contentToParse = contentToParse.trim();

    _isFrontMatter = _isFrontMatterContent(widget.textContent, widget.chapterTitle);
    _contentStyle = _resolveContentStyle();

    contentToParse = contentToParse.replaceAll(RegExp(r'<\?xml[^?]*\?>\s*'), '');

    final bodyMatch = RegExp(r'<body[^>]*>(.*?)</body>', dotAll: true).firstMatch(contentToParse);
    if (bodyMatch != null) {
      contentToParse = bodyMatch.group(1) ?? contentToParse;
    }

    var document = html_parser.parseFragment(contentToParse);

    List<InlineSpan> spans = [];

    double maxWidth = pageSize.width - 32.w;

    List<dom.Node> nodesToParse = document.nodes.toList();
    if (nodesToParse.isEmpty && widget.textContent.trim().isNotEmpty) {
      final textNode = dom.Text(widget.textContent);
      nodesToParse = [textNode];
    }

    final chapterTitleLower = widget.chapterTitle.trim().toLowerCase();

    for (var i = 0; i < nodesToParse.length; i++) {
      final node = nodesToParse[i];

      String nodeText = '';
      if (node is dom.Element) {
        nodeText = node.text.trim();
      } else if (node is dom.Text) {
        nodeText = node.text.trim();
      }

      if (chapterTitleLower.isNotEmpty && nodeText.isNotEmpty) {
        final nodeTextLower = nodeText.toLowerCase();
        if (nodeTextLower == chapterTitleLower || chapterTitleLower.contains(nodeTextLower) && nodeText.length > 2) {
          continue;
        }
      }

      spans.add(await _parseNode(node, maxWidth, isPoetry: false));
    }

    // Recursive function to check if a span has real content
    bool hasRealContent(InlineSpan span) {
      if (span is WidgetSpan) return true;

      if (span is TextSpan) {
        // Check direct text
        if (span.text != null && span.text!.trim().isNotEmpty) {
          return true;
        }

        // Check children recursively
        if (span.children != null && span.children!.isNotEmpty) {
          for (var child in span.children!) {
            if (hasRealContent(child)) {
              return true;
            }
          }
        }
      }

      return false;
    }

    bool hasContent = spans.any((span) => hasRealContent(span));

    if (!hasContent) {
      _pageSpans.clear();
      _pageSpans.add(const TextSpan(text: ''));

      _finalizePages();
      return;
    }

    await _paginateFlattened(spans, pageSize);
  }

  Future<InlineSpan> _parseNode(dom.Node node, double maxWidth, {bool isPoetry = false}) async {
    if (node is dom.Element) {
    } else if (node is dom.Text) {
      final preview = node.text.trim().length > 50 ? node.text.trim().substring(0, 50) + '...' : node.text.trim();
    }

    if (node is dom.Text) {
      String text = node.text;

      text = text.replaceAll('\u00A0', ' ');
      text = text.replaceAll('\u200B', '');
      text = text.replaceAll('\u2009', ' ');
      text = text.replaceAll('\u202F', ' ');

      // For poetry, preserve line breaks and multiple spaces
      // For prose, flatten all whitespace to single spaces
      if (!isPoetry) {
        text = text.replaceAll(RegExp(r'\s+'), ' ');
        // Ensure a space after punctuation when missing (e.g., ";Word" -> "; Word")
        text = text.replaceAllMapped(
          RegExp(r'([\.,;:!?])([A-Za-z\u0400-\u04FF])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
      }

      if (text.trim().isEmpty) {
        return const TextSpan(text: '');
      }

      text = text.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
      text = text.replaceAll(RegExp(r'([([«])\s+'), '\$1');

      return TextSpan(
        text: text,
        style: _contentStyle.copyWith(
          color: _contentStyle.color,
          fontFamily: 'SFPro',
          height: _isFrontMatter ? 1.25 : 1.5,
          letterSpacing: _isFrontMatter ? 0.0 : 0.1,
          wordSpacing: _isFrontMatter ? 0.0 : 0.5,
          overflow: TextOverflow.visible,
        ),
      );
    } else if (node is dom.Element) {
      if (node.localName == 'img') {
        return await _handleImageNode(node, maxWidth);
      } else if (node.localName == 'br') {
        return const TextSpan(text: "\n");
      } else if (node.localName == 'p' || node.localName == 'div') {
        // DEBUG: Check if this paragraph has italic children (em, i)
        bool hasItalicChild = false;
        String childrenDebug = '';
        for (var child in node.children) {
          if (child.localName == 'em' || child.localName == 'i') {
            hasItalicChild = true;
          }
          childrenDebug += '<${child.localName}> ';
        }

        // Check if this element contains poetry/verse
        final isPoetry = _isPoeticElement(node);

        if (isPoetry) {
          // For poetry, extract text from each child div/p as separate lines

          // Find all paragraph/div elements and extract their text as lines
          List<String> poetryLines = [];
          Set<String> addedLines = {}; // Avoid duplicates

          void extractPoetryLines(dom.Element element) {
            // First check direct children
            for (var child in element.children) {
              if (child.localName == 'div' || child.localName == 'p') {
                // Check if this div has class="paragraph" or similar
                String lineText = child.text.trim();
                if (lineText.isNotEmpty && lineText.length < 100 && !addedLines.contains(lineText)) {
                  poetryLines.add(lineText);
                  addedLines.add(lineText);
                }
              } else if (child.localName == 'blockquote') {
                // Handle blockquote - extract its child paragraphs
                extractPoetryLines(child);
              }
            }
          }

          extractPoetryLines(node);

          // If no child divs found, try splitting by <br> or just use full text
          if (poetryLines.isEmpty) {
            String poetryHtml = node.innerHtml;
            poetryHtml = poetryHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
            poetryHtml = poetryHtml.replaceAll(RegExp(r'<[^>]+>'), '');
            poetryHtml = poetryHtml.replaceAll('&nbsp;', ' ');
            poetryLines = poetryHtml.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          }

          String poetryText = poetryLines.join('\n');
          final centerPoetry = _shouldCenterPoetry(poetryLines);

          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              width: maxWidth,
              padding: EdgeInsets.only(bottom: _isFrontMatter ? 4.h : 6.h, top: _isFrontMatter ? 2.h : 4.h),
              child: Text(
                poetryText,
                textAlign: centerPoetry ? TextAlign.center : TextAlign.left,
                style: _contentStyle.copyWith(
                  color: _contentStyle.color,
                  fontFamily: 'SFPro',
                  height: _isFrontMatter ? 1.3 : 1.4,
                  letterSpacing: _isFrontMatter ? 0.0 : 0.1,
                  wordSpacing: _isFrontMatter ? 0.0 : 0.5,
                ),
              ),
            ),
          );
        } else {
          // Check if this paragraph is a section divider (Roman numerals, "* * *", etc.)
          final paragraphText = node.text.trim();
          final isSectionDivider = _isSectionDividerText(paragraphText);

          if (isSectionDivider) {
            // Center section dividers (Roman numerals, "* * *", etc.)
            return WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Container(
                width: maxWidth,
                padding: EdgeInsets.symmetric(vertical: _isFrontMatter ? 4.h : 8.h),
                alignment: Alignment.center,
                child: Text(
                  paragraphText,
                  textAlign: TextAlign.center,
                  style: _contentStyle.copyWith(
                    color: _contentStyle.color,
                    fontFamily: 'SFPro',
                    height: _isFrontMatter ? 1.25 : 1.5,
                  ),
                ),
              ),
            );
          }

          // For prose, use regular indented paragraph
          List<InlineSpan> children = [];

          if (!_isFrontMatter) {
            children.add(TextSpan(
              text: '\u00A0\u00A0\u00A0\u00A0\u00A0',
              style: _contentStyle,
            ));
          }

          for (var child in node.nodes) {
            final span = await _parseNode(child, maxWidth, isPoetry: false);
            children.add(span);
          }

          children.add(const TextSpan(text: '\n'));

          return TextSpan(
            children: children,
          );
        }
      } else if (node.localName == 'h1' || node.localName == 'h2' || node.localName == 'h3') {
        List<InlineSpan> children = [];

        children.add(const TextSpan(text: '\n'));

        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth, isPoetry: false));
        }

        children.add(const TextSpan(text: '\n\n'));

        return TextSpan(
          children: children,
          style: _contentStyle.copyWith(
            color: _contentStyle.color,
            fontSize: (_contentStyle.fontSize ?? 16) + 4,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.normal,
            height: _isFrontMatter ? 1.25 : 1.5,
          ),
        );
      } else if (node.localName == 'blockquote') {
        // Check if this is a nested blockquote with author (common pattern in EPUBs)
        String? authorName;
        String? quoteText;

        // Pattern 1: Nested blockquote with italic author
        // <blockquote class="epigraph">
        //   <div><div class="paragraph">Quote text</div>
        //   <blockquote><i>Author</i></blockquote></div>
        // </blockquote>

        // Find nested blockquote with italic element
        for (var child in node.querySelectorAll('blockquote')) {
          var italicElement = child.querySelector('i') ?? child.querySelector('em');
          if (italicElement != null) {
            authorName = italicElement.text.trim();
            break;
          }
        }

        // Extract quote text (exclude nested blockquotes)
        StringBuffer textBuffer = StringBuffer();
        void extractQuoteText(dom.Element element, {bool skipNestedBlockquote = false}) {
          for (var child in element.nodes) {
            if (child is dom.Element) {
              // Skip nested blockquotes (they contain the author)
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
        quoteText = textBuffer.toString().trim();

        if (quoteText.isEmpty) {
          return const TextSpan(text: '');
        }

        // Clean up the quote text
        quoteText = quoteText.replaceAll('\u00A0', ' ');
        quoteText = quoteText.replaceAll('\u200B', '');
        quoteText = quoteText.replaceAll('\u2009', ' ');
        quoteText = quoteText.replaceAll('\u202F', ' ');
        quoteText = quoteText.replaceAll(RegExp(r'\s+'), ' ');
        quoteText = quoteText.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
        quoteText = quoteText.replaceAll(RegExp(r'([([«])\s+'), '\$1');
        quoteText = quoteText.trim();

        List<InlineSpan> spans = [];

        // Add top spacing
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(height: 20.h),
        ));

        // Add quote text (Apple Books style: centered, elegant)
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
              style: _contentStyle.copyWith(
                color: _contentStyle.color,
                fontStyle: FontStyle.normal,
                fontSize: (_contentStyle.fontSize ?? 12) - 2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ));

        // Add author name if found (Apple Books style: centered)
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
                style: _contentStyle.copyWith(
                  color: _contentStyle.color,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.bold,
                  fontSize: (_contentStyle.fontSize ?? 12) * 0.95,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ));
        } else {
          // Add minimal bottom spacing if no author
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(height: 8.h),
          ));
        }

        return TextSpan(children: spans);
      } else if (node.localName == 'cite') {
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

        // Check if previous sibling was a long italic (quote) - if so, skip (already rendered with quote)
        var prevSibling = node.previousElementSibling;
        if (prevSibling == null && node.parent != null) {
          prevSibling = node.parent!.previousElementSibling;
        }

        if (prevSibling != null && (prevSibling.localName == 'em' || prevSibling.localName == 'i') && prevSibling.text.trim().length > 80) {
          // Already shown with the quote above, skip
          return const TextSpan(text: '');
        }

        // If cite is standalone (not after quote), show it like Apple Books
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
                style: _contentStyle.copyWith(
                  color: _contentStyle.color,
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w600,
                  height: _isFrontMatter ? 1.2 : 1.3,
                ),
              ),
            ),
          ),
        );
      } else if (node.localName == 'em' || node.localName == 'i') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth, isPoetry: isPoetry));
        }

        // Check if this is a long italic text (likely a quote)
        final text = node.text.trim();
        final isLongQuote = text.length > 80; // Reduced threshold

        if (isLongQuote) {
          // Check for following author/cite element
          String? authorText;
          var nextSibling = node.nextElementSibling;

          // Look for author in next sibling or parent's next sibling
          if (nextSibling == null && node.parent != null) {
            nextSibling = node.parent!.nextElementSibling;
          }

          if (nextSibling != null) {
            // Check if next sibling is <cite>, <em> with short text, or <p> with italic
            if (nextSibling.localName == 'cite' ||
                (nextSibling.localName == 'em' && nextSibling.text.trim().length < 50) ||
                (nextSibling.localName == 'i' && nextSibling.text.trim().length < 50) ||
                (nextSibling.localName == 'p' && nextSibling.querySelector('em') != null)) {
              authorText = nextSibling.text.trim();
            }
          }

          // Render as centered quote with optional author
          List<Widget> quoteWidgets = [
            Container(
              width: maxWidth,
              padding: EdgeInsets.fromLTRB(maxWidth * 0.1, 12.h, maxWidth * 0.1, 8.h),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: _contentStyle.copyWith(
                  color: _contentStyle.color,
                  fontStyle: FontStyle.normal,
                  height: _isFrontMatter ? 1.25 : 1.5,
                  fontSize: _contentStyle.fontSize,
                ),
              ),
            ),
          ];

          // Add author if found
          if (authorText != null && authorText.isNotEmpty) {
            quoteWidgets.add(
              Container(
                width: maxWidth,
                padding: EdgeInsets.fromLTRB(maxWidth * 0.1, 0.h, maxWidth * 0.1, 12.h),
                child: Text(
                  authorText,
                  textAlign: TextAlign.center,
                  style: _contentStyle.copyWith(
                    color: _contentStyle.color,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w500,
                    height: _isFrontMatter ? 1.2 : 1.3,
                    fontSize: _contentStyle.fontSize,
                  ),
                ),
              ),
            );
          }
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              width: maxWidth,
              padding: EdgeInsets.symmetric(
                vertical: _isFrontMatter ? 6.h : 10.h, // Reduced from 12.h/20.h
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: _contentStyle.copyWith(
                  color: _contentStyle.color,
                  fontStyle: FontStyle.normal,
                  height: 1.4, // Consistent line height
                  fontSize: _contentStyle.fontSize,
                ),
              ),
            ),
          );
          // return WidgetSpan(
          //   alignment: PlaceholderAlignment.baseline,
          //   baseline: TextBaseline.alphabetic,
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.center,
          //     mainAxisSize: MainAxisSize.min,
          //     children: quoteWidgets,
          //   ),
          // );
        }

        return TextSpan(
          children: children,
          style: _contentStyle.copyWith(
            color: _contentStyle.color,
            fontStyle: FontStyle.normal,
          ),
        );
      } else if (node.localName == 'strong' || node.localName == 'b') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth, isPoetry: isPoetry));
        }
        return TextSpan(
          children: children,
          style: _contentStyle.copyWith(
            color: _contentStyle.color,
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth, isPoetry: isPoetry));
        }
        return TextSpan(children: children);
      }
    }
    return const TextSpan(text: "");
  }

  Future<InlineSpan> _handleImageNode(dom.Element node, double maxWidth) async {
    String? src = node.attributes['src'];

    if (src == null || widget.epubBook == null) {
      return const TextSpan(text: "");
    }

    final imageContent = _findImage(src);

    if (imageContent == null) {
      return _createNotFoundWidget(src);
    }

    try {
      final bytes = imageContent.Content as List<int>;
      final uint8list = Uint8List.fromList(bytes);
      final codec = await ui.instantiateImageCodec(uint8list);
      final frameInfo = await codec.getNextFrame();
      final imageWidth = frameInfo.image.width.toDouble();
      final imageHeight = frameInfo.image.height.toDouble();
      double availableWidth = maxWidth * 0.95;
      double displayWidth = imageWidth;
      double displayHeight = imageHeight;

      if (displayWidth > availableWidth) {
        displayWidth = availableWidth;
        displayHeight = (displayWidth / imageWidth) * imageHeight;
      }

      double maxDisplayHeight = _initializedRenderBox.size.height * 0.7;
      if (displayHeight > maxDisplayHeight) {
        displayHeight = maxDisplayHeight;
        displayWidth = (displayHeight / imageHeight) * imageWidth;
      }

      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                uint8list,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImageError(displayWidth);
                },
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      return _createErrorWidget(src, maxWidth);
    }
  }

  Widget _buildImageError(double width) {
    return Container(
      width: width,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
          SizedBox(height: 8),
          Text(
            'Image error',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  InlineSpan _createErrorWidget(String src, double maxWidth) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        width: maxWidth * 0.9,
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          border: Border.all(color: Colors.orange[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 24, color: Colors.orange[700]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    src.split('/').last,
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InlineSpan _createNotFoundWidget(String src) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 20, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Image not found: ${src.split('/').last}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  EpubByteContentFile? _findImage(String src) {
    if (widget.epubBook?.Content?.Images == null) {
      return null;
    }

    final images = widget.epubBook!.Content!.Images!;
    if (images.containsKey(src)) {
      return images[src];
    }

    try {
      final decoded = Uri.decodeFull(src);
      if (images.containsKey(decoded)) {
        return images[decoded];
      }
    } catch (_) {}

    final noLeading = src.startsWith('/') ? src.substring(1) : src;
    if (images.containsKey(noLeading)) {
      return images[noLeading];
    }

    String cleanSrc = src.replaceAll('../', '').replaceAll('./', '').replaceAll('\\', '/').trim();

    if (images.containsKey(cleanSrc)) {
      return images[cleanSrc];
    }

    final filename = cleanSrc.split('/').last;

    for (var key in images.keys) {
      final cleanKey = key.replaceAll('\\', '/');

      if (cleanKey == cleanSrc || cleanKey.endsWith(filename) || cleanKey.toLowerCase().endsWith(filename.toLowerCase())) {
        return images[key];
      }
    }

    final lowerSrc = cleanSrc.toLowerCase();
    for (var key in images.keys) {
      if (key.toLowerCase() == lowerSrc) {
        return images[key];
      }
    }

    return null;
  }

  Future<void> _paginateFlattened(List<InlineSpan> allSpans, Size pageSize) async {
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

    for (var s in allSpans) flatten(s);

    double horizontalPadding = 10.w;
    if (pageSize.width >= 600) {
      horizontalPadding = 20.w;
    }
    double maxWidth = pageSize.width - horizontalPadding;

    // Container padding'leri ile senkronize olmalı (selectable_text_with_addnote.dart)
    // Increased reserved space to prevent text from being cut off at bottom
    double containerPadding = _isFrontMatter ? 14.h : 24.h;
    double chapterHeaderSpace = _isFrontMatter ? 8.h : 20.h;
    double bottomSafeArea = _isFrontMatter ? 8.h : 16.h; // Extra space for bottom navigation area

    double reservedSpace = containerPadding + chapterHeaderSpace + bottomSafeArea;

    double maxHeight = pageSize.height - reservedSpace;

    // FIRST PASS: Calculate total content height to see if it fits in one page
    double totalContentHeight = 0;
    int totalChars = 0;
    for (var span in flatSpans) {
      if (span is TextSpan && span.text != null) {
        totalChars += span.text!.length;
      }
      if (span is WidgetSpan) {
        try {
          TextPainter painter = TextPainter(
            text: TextSpan(children: [span]),
            textDirection: TextDirection.ltr,
            textScaleFactor: 1.0,
          );
          painter.layout(maxWidth: maxWidth);
          totalContentHeight += painter.height;
          painter.dispose();
        } catch (e) {
          totalContentHeight += 100.h;
        }
      } else if (span is TextSpan && span.text != null) {
        TextPainter painter = TextPainter(
          text: TextSpan(text: span.text, style: span.style),
          textDirection: TextDirection.ltr,
          textScaleFactor: 1.0,
        );
        painter.layout(maxWidth: maxWidth);
        totalContentHeight += painter.height;
        painter.dispose();
      }
    }

    double pageRatio = totalContentHeight / maxHeight;
    int estimatedPages = pageRatio.ceil();

    // AGGRESSIVE: If content fits in 1 page (with extra overflow allowed for front matter), force single page
    // FIXED: Reduced threshold from 2.4/1.5 to 1.05.
    // The previous high threshold was forcing 2+ pages of content into a single page,
    // especially for content classified as "Front Matter" (threshold 2.4).
    final singlePageThreshold = 1.0;
    // CRITICAL FIX: Ensure we don't force single page if char count is too high!
    // Must respect the absolute max limit (1050)
    if (pageRatio <= singlePageThreshold && totalChars <= 1050) {
      List<InlineSpan> allSpansForPage = List.from(flatSpans);
      _pageSpans.add(TextSpan(children: allSpansForPage));
      _finalizePages();
      return;
    }

    // For all content, distribute evenly across pages (Apple Books style)
    // Calculate target height per page for even distribution
    double targetHeightPerPage = totalContentHeight / estimatedPages;

    // Use slightly less than maxHeight to ensure content fits comfortably
    double safeMaxHeight = maxHeight * 0.95;
    if (targetHeightPerPage > safeMaxHeight) {
      targetHeightPerPage = safeMaxHeight;
    }

    // Dynamic character limits based on font size AND screen size
    // Base values for 13px font size (our reference point)
    const double baseFontSize = 13.0;
    const int baseMinChars = 800;
    const int baseMaxChars = 1000;

    // Calculate Screen Capacity Factor
    // Reference content area (approx standard phone safe area: 350w x 600h)
    const double referenceArea = 350.0 * 600.0; // ~210,000 sq pixels
    final double currentArea = maxWidth * maxHeight;

    double screenCapacityFactor = currentArea / referenceArea;

    // Clamp factor to prevent extreme scaling (0.8x to 1.1x)
    // This ensures we adjust for size but don't go crazy on tablets or tiny screens
    // Reduced upper bound significantly to prevent "wall of text"
    if (screenCapacityFactor < 0.8) screenCapacityFactor = 0.8;
    if (screenCapacityFactor > 1.1) screenCapacityFactor = 1.1;

    // Get current font size
    final currentFontSize = _contentStyle.fontSize ?? baseFontSize;

    // Calculate scaling factor (inverse relationship)
    final fontScaleFactor = baseFontSize / currentFontSize;

    // Calculate dynamic limits combining both factors
    int minCharsPerPage = (baseMinChars * fontScaleFactor * screenCapacityFactor).round();
    int maxCharsPerPage = (baseMaxChars * fontScaleFactor * screenCapacityFactor).round();

    // Safety: Strictly limit chars per page to prevent overflow
    // Hard cap at 1050 to ensure we never get 1600+ chars
    int absoluteMax = 1050;
    if (maxCharsPerPage > absoluteMax) maxCharsPerPage = absoluteMax;

    // Ensure logical bounds
    if (maxCharsPerPage < 500) maxCharsPerPage = 500;
    if (minCharsPerPage > maxCharsPerPage) minCharsPerPage = maxCharsPerPage - 50;

    // Log detailed font size and character count information
    print('═══════════════════════════════════════════════════════');
    print('📊 PAGINATION CHARACTER COUNT CALCULATION');
    print('───────────────────────────────────────────────────────');
    print('Total Content Characters: $totalChars');
    print('Current Font Size: ${currentFontSize}px');
    print('Scale Factor: ${fontScaleFactor.toStringAsFixed(2)}');
    print('Screen Capacity Factor: ${screenCapacityFactor.toStringAsFixed(2)}');
    print('Calculated Range: $minCharsPerPage - $maxCharsPerPage chars/page');
    print('───────────────────────────────────────────────────────');
    print('📐 CHARACTER COUNT EXAMPLES BY FONT SIZE:');
    print('Font size 10px: ~${(baseMinChars * (baseFontSize / 10)).round()}-${(baseMaxChars * (baseFontSize / 10)).round()} characters per page');
    print('Font size 11px: ~${(baseMinChars * (baseFontSize / 11)).round()}-${(baseMaxChars * (baseFontSize / 11)).round()} characters per page');
    print('Font size 12px: ~${(baseMinChars * (baseFontSize / 12)).round()}-${(baseMaxChars * (baseFontSize / 12)).round()} characters per page');
    print('Font size 13px: $baseMinChars-$baseMaxChars characters per page (BASE)');
    print('Font size 14px: ~${(baseMinChars * (baseFontSize / 14)).round()}-${(baseMaxChars * (baseFontSize / 14)).round()} characters per page');
    print('Font size 15px: ~${(baseMinChars * (baseFontSize / 15)).round()}-${(baseMaxChars * (baseFontSize / 15)).round()} characters per page');
    print('Font size 16px: ~${(baseMinChars * (baseFontSize / 16)).round()}-${(baseMaxChars * (baseFontSize / 16)).round()} characters per page');
    print('Font size 18px: ~${(baseMinChars * (baseFontSize / 18)).round()}-${(baseMaxChars * (baseFontSize / 18)).round()} characters per page');
    print('Font size 20px: ~${(baseMinChars * (baseFontSize / 20)).round()}-${(baseMaxChars * (baseFontSize / 20)).round()} characters per page');
    print('Font size 22px: ~${(baseMinChars * (baseFontSize / 22)).round()}-${(baseMaxChars * (baseFontSize / 22)).round()} characters per page');
    print('Font size 24px: ~${(baseMinChars * (baseFontSize / 24)).round()}-${(baseMaxChars * (baseFontSize / 24)).round()} characters per page');
    print('═══════════════════════════════════════════════════════');

    // REMOVED: Height-based adjustment that was overriding font-size scaling
    // The previous logic was forcing all font sizes to use the same character count,
    // which defeated the purpose of dynamic font-size-based pagination.
    // Now we trust the font-size-based calculation exclusively.

    // Calculate estimated pages based on character count
    // This ensures font size changes affect pagination
    int charBasedEstimatedPages = (totalChars / maxCharsPerPage).ceil();

    // Use the MAXIMUM of height-based and character-based estimates
    // This ensures we respect both constraints
    int finalEstimatedPages = charBasedEstimatedPages > estimatedPages ? charBasedEstimatedPages : estimatedPages;

    print('📊 Page Estimation:');
    print('   Height-based: $estimatedPages pages');
    print('   Character-based: $charBasedEstimatedPages pages');
    print('   Final estimate: $finalEstimatedPages pages');
    print('📏 Final limits -> Min chars: $minCharsPerPage, Max chars: $maxCharsPerPage');

    // Calculate total character count and track each span's character count
    List<int> spanCharCounts = [];

    for (var span in flatSpans) {
      int charCount = 0;
      if (span is TextSpan && span.text != null) {
        charCount = span.text!.length;
      }
      spanCharCounts.add(charCount);
    }

    // REMOVED optimization: We ALWAYS want to run the distribution loop
    // to ensure splitting works correctly for single large paragraphs.

    // Distribute content across pages based on character count
    List<List<InlineSpan>> allPages = [];
    List<InlineSpan> currentPageList = [];
    int currentPageChars = 0;
    for (int i = 0; i < flatSpans.length; i++) {
      final span = flatSpans[i];
      final spanChars = spanCharCounts[i];

      // Check if adding this span would exceed the max character limit
      if (currentPageChars + spanChars > maxCharsPerPage) {
        if (currentPageList.isNotEmpty && currentPageChars >= minCharsPerPage) {
          allPages.add(List.from(currentPageList));
          currentPageList.clear();
          currentPageChars = 0;
        } else {}

        // If the span itself fits now (on fresh page), just add it
        if (spanChars <= maxCharsPerPage) {
          currentPageList.add(span);
          currentPageChars += spanChars;
          continue;
        } else {}

        // The span is too large for a single page (even a fresh one) -> We MUST split it
        if (span is TextSpan && span.text != null) {
          String remainingText = span.text!;
          TextStyle? style = span.style;

          while (remainingText.isNotEmpty) {
            // How much space do we have left on current page?
            int spaceLeft = maxCharsPerPage - currentPageChars;

            // If space is too small (e.g. < 100 chars), just break page to start fresh
            if (spaceLeft < 100 && currentPageList.isNotEmpty) {
              allPages.add(List.from(currentPageList));
              currentPageList.clear();
              currentPageChars = 0;
              spaceLeft = maxCharsPerPage;
            }

            if (remainingText.length <= spaceLeft) {
              // Fits completely
              currentPageList.add(TextSpan(text: remainingText, style: style));
              currentPageChars += remainingText.length;
              remainingText = '';
            } else {
              // Need to split. Find last space before limit
              int splitIndex = remainingText.lastIndexOf(' ', spaceLeft);
              if (splitIndex == -1 || splitIndex < spaceLeft * 0.7) {
                // If no space found nearby, just hard split at limit
                splitIndex = spaceLeft;
              }

              String textPart = remainingText.substring(0, splitIndex);
              remainingText = remainingText.substring(splitIndex); // Keep space or not? usually keep space at start of next line or drop it?
              // Better: trimmed textPart? No, preserve spacing.
              // Let's drop the leading space of the next part if it's a space split
              if (remainingText.startsWith(' ')) {
                remainingText = remainingText.substring(1);
              }

              currentPageList.add(TextSpan(text: textPart, style: style));
              currentPageChars += textPart.length;

              // Force new page
              allPages.add(List.from(currentPageList));
              currentPageList.clear();
              currentPageChars = 0;
            }
          }
        } else {
          // Non-text span (widget) that is supposedly huge? Rare, but just add it to avoid loop
          // Or if it's a widget, we can't really split it.
          // If we just cleared the page, add it anyway even if it exceeds
          if (currentPageList.isEmpty) {
            currentPageList.add(span);
            currentPageChars += spanChars;
            // Force break after this huge widget
            allPages.add(List.from(currentPageList));
            currentPageList.clear();
            currentPageChars = 0;
          } else {
            // Should have been handled by first check (break page), but if it falls here:
            // Break page and add to next
            allPages.add(List.from(currentPageList));
            currentPageList.clear();
            currentPageList.add(span);
            currentPageChars += spanChars;
          }
        }
      } else {
        // Fits normally
        print('   ✅ Fits normally, adding to current page');
        currentPageList.add(span);
        currentPageChars += spanChars;
      }
    }

    // Add remaining content as last page
    if (currentPageList.isNotEmpty) {
      allPages.add(currentPageList);
    }

    // Convert to TextSpans
    for (var pageSpans in allPages) {
      _pageSpans.add(TextSpan(children: pageSpans));
    }

    _finalizePages();
  }

  String _addHyphenIfLineBreaksMidWord(String lineText, String fullText, int endOffset) {
    if (endOffset >= fullText.length) return lineText;

    if (lineText.isEmpty ||
        lineText.endsWith(' ') ||
        lineText.endsWith('\n') ||
        lineText.endsWith('-') ||
        lineText.endsWith('.') ||
        lineText.endsWith(',') ||
        lineText.endsWith('!') ||
        lineText.endsWith('?')) {
      return lineText;
    }

    if (endOffset < fullText.length) {
      final nextChar = fullText[endOffset];
      if (nextChar == ' ' || nextChar == '\n' || nextChar == '.' || nextChar == ',' || nextChar == '!' || nextChar == '?') {
        return lineText;
      }
    }

    final match = RegExp(r'[a-zA-Z\u0400-\u04FF\u0500-\u052F]{6,}$').firstMatch(lineText);
    if (match == null) return lineText;

    final brokenWord = match.group(0);
    if (brokenWord == null || brokenWord.length < 6) return lineText;

    final remainingChars = lineText.length - lineText.lastIndexOf(RegExp(r'\s')) - 1;
    if (remainingChars < 3) return lineText;

    return lineText + '-';
  }

  String _extractTextFromSpan(InlineSpan span) {
    StringBuffer buffer = StringBuffer();

    void extractText(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text != null) {
          buffer.write(s.text);
        }
        if (s.children != null) {
          for (var child in s.children!) {
            extractText(child);
          }
        }
      }
      // WidgetSpans don't contain text we can easily extract
    }

    extractText(span);
    return buffer.toString();
  }

  void _finalizePages() {
    final bottomNavHeight = widget.showNavBar ? 10.0 : 0.0;

    // Remove leading empty pages so chapter jumps don't land on blank pages
    if (_pageSpans.length > 1) {
      while (_pageSpans.isNotEmpty && !_spanHasRealContent(_pageSpans.first)) {
        _pageSpans.removeAt(0);
      }
    }

    pages = _pageSpans.asMap().entries.map((entry) {
      int index = entry.key;
      TextSpan contentSpan = entry.value;

      final isFirstPageOfChapter = index == 0;

      // Extract and log page text
      String pageText = _extractTextFromSpan(contentSpan);

      return BookPageBuilder.buildBookPageSpan(
        context: context,
        contentSpan: contentSpan,
        style: _contentStyle,
        textDirection: RTLHelper.getTextDirection(widget.textContent),
        bookId: widget.bookId,
        onTextTap: widget.onTextTap,
        isFirstPage: isFirstPageOfChapter,
        chapterTitle: widget.chapterTitle,
        pageNumber: index + 1,
        totalPages: _pageSpans.length,
        backgroundColor: widget.style.backgroundColor,
        bottomNavHeight: bottomNavHeight,
      );
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pages.isNotEmpty) {
        final startIndex = widget.starterPageIndex < pages.length ? widget.starterPageIndex : 0;
        // Notify initial page so outer widgets (progress bar/theme) update immediately
        widget.onPageFlip(startIndex, pages.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: paginateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingWidget(
              height: 100,
              animationWidth: 50,
              animationHeight: 50,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(18.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading content',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (pages.isEmpty) {
          final isTitlePage = widget.textContent.trim().length < 200 && widget.textContent.toLowerCase().contains(widget.chapterTitle.toLowerCase());

          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isTitlePage ? Icons.auto_stories : Icons.warning_amber_rounded, size: 64, color: isTitlePage ? Colors.blue : Colors.orange),
                  SizedBox(height: 16.h),
                  Text(
                    isTitlePage ? widget.chapterTitle : 'Içerik görüntülenemiyor',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.style.color ?? Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    isTitlePage ? 'Bu bir başlık sayfasıdır. İçeriği okumak için sonraki bölüme geçin.' : 'Bu bölüm yüklenirken bir sorun oluştu. Lütfen tekrar deneyin.',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: (widget.style.color ?? Colors.black).withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      rePaginate();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Tekrar dene'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    key: _pageKey,
                    child: PageFlipWidget(
                      key: _pageController,
                      initialIndex: widget.starterPageIndex != 0 ? (pages.isNotEmpty && widget.starterPageIndex < pages.length ? widget.starterPageIndex : 0) : widget.starterPageIndex,
                      onPageFlip: (pageIndex) {
                        _currentPageIndex = pageIndex;
                        _handler.currentPage.value = pageIndex + 1;

                        // Pass the actual chapter page count (pages.length), NOT the book total
                        // show_epub.dart will handle converting this to book-wide page numbers
                        widget.onPageFlip(pageIndex, pages.length);
                        // Don't auto-trigger onLastPage here - let PageFlipWidget handle it
                        // when user actually tries to swipe beyond last page
                      },
                      onLastPageSwipe: () {
                        widget.onLastPage(_currentPageIndex, pages.length);
                      },
                      backgroundColor: widget.style.backgroundColor ?? const Color(0xFFFFFFFF),
                      lastPage: widget.lastWidget,
                      children: pages,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
