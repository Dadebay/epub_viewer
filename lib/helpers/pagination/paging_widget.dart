import 'package:cosmos_epub/helpers/pagination/html_parsing_helpers.dart';
import 'package:cosmos_epub/helpers/pagination/image_handler.dart';
import 'package:cosmos_epub/helpers/pagination/node_parser.dart';
import 'package:cosmos_epub/helpers/pagination/page_distribution.dart';
import 'package:cosmos_epub/helpers/pagination/paging_text_handler.dart';
import 'package:cosmos_epub/helpers/selectable_text_with_addnote.dart';
import 'package:cosmos_epub/helpers/functions.dart';
import 'package:cosmos_epub/page_flip/page_flip_widget.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

export 'package:cosmos_epub/helpers/pagination/paging_text_handler.dart';

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
    this.subchapterTitles = const [],
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
  final List<String> subchapterTitles;

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

  late ImageHandler _imageHandler;
  late NodeParser _nodeParser;
  late PageDistributor _pageDistributor;

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

  void rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final renderObject = context.findRenderObject();
      if (renderObject == null) {
        Future.delayed(const Duration(milliseconds: 100), () {
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

  void _initializeHelpers() {
    _imageHandler = ImageHandler(
      epubBook: widget.epubBook,
      maxDisplayHeight: _initializedRenderBox.size.height * 0.7,
    );

    _nodeParser = NodeParser(
      contentStyle: _contentStyle,
      isFrontMatter: _isFrontMatter,
      chapterTitle: widget.chapterTitle,
      subchapterTitles: widget.subchapterTitles,
      onImageNode: _imageHandler.handleImageNode,
    );

    _pageDistributor = PageDistributor(
      contentStyle: _contentStyle,
      isFrontMatter: _isFrontMatter,
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

    _isFrontMatter = HtmlParsingHelpers.isFrontMatterContent(widget.textContent, widget.chapterTitle);
    _contentStyle = _resolveContentStyle();

    _initializeHelpers();

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

      // SADECE tam eşleşme durumunda atla, kısmi eşleşmeleri ATLAMAYALIM
      // çünkü "Часть I" ve "Проблемы" gibi başlıklar bold olmalı
      if (chapterTitleLower.isNotEmpty && nodeText.isNotEmpty) {
        final nodeTextLower = nodeText.toLowerCase();
        // Sadece TAM eşleşme durumunda atla
        if (nodeTextLower == chapterTitleLower) {
          print('⏭️ ATLANDI (tam eşleşme): "$nodeText"');
          continue;
        }
      }

      spans.add(await _nodeParser.parseNode(node, maxWidth, isPoetry: false));
    }

    bool hasContent = spans.any((span) => _spanHasRealContent(span));

    if (!hasContent) {
      _pageSpans.clear();
      _pageSpans.add(const TextSpan(text: ''));
      _finalizePages();
      return;
    }

    final distributedPages = _pageDistributor.distributeContent(spans, pageSize);
    _pageSpans.addAll(distributedPages);

    _finalizePages();
  }

  void _finalizePages() {
    final bottomNavHeight = widget.showNavBar ? 10.0 : 0.0;

    if (_pageSpans.length > 1) {
      while (_pageSpans.isNotEmpty && !_spanHasRealContent(_pageSpans.first)) {
        _pageSpans.removeAt(0);
      }
    }

    pages = _pageSpans.asMap().entries.map((entry) {
      int index = entry.key;
      TextSpan contentSpan = entry.value;

      final isFirstPageOfChapter = index == 0;

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
          return _buildEmptyState();
        }

        return _buildPageFlipView();
      },
    );
  }

  Widget _buildEmptyState() {
    final isTitlePage = widget.textContent.trim().length < 200 && widget.textContent.toLowerCase().contains(widget.chapterTitle.toLowerCase());

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTitlePage ? Icons.auto_stories : Icons.warning_amber_rounded,
              size: 64,
              color: isTitlePage ? Colors.blue : Colors.orange,
            ),
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
              onPressed: rePaginate,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageFlipView() {
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
                    widget.onPageFlip(pageIndex, pages.length);
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
  }
}
