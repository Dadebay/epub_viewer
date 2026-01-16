import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'components/constants.dart';
import 'helpers/pagination.dart';
import 'helpers/progress_singleton.dart';
import 'models/chapter_model.dart';
import 'helpers/epub_cache_helper.dart';
import 'helpers/epub_chapter_helper.dart';
import 'helpers/epub_pagination_helper.dart';
import 'helpers/epub_chapter_list_builder.dart';
import 'helpers/epub_toc_helper.dart';
import 'helpers/epub_theme_helper.dart';
import 'helpers/epub_content_helper.dart';
import 'helpers/epub_background_calculator.dart';
import 'widgets/epub_bottom_nav_widget.dart';
import 'widgets/epub_header_widget.dart';

late BookProgressSingleton bookProgress;

const double DESIGN_WIDTH = 375;
const double DESIGN_HEIGHT = 812;

String selectedFont = 'Segoe';
List<String> fontNames = [
  "Segoe",
  "Alegreya",
  "Amazon Ember",
  "Atkinson Hyperlegible",
  "Bitter Pro",
  "Bookerly",
  "Droid Sans",
  "EB Garamond",
  "Gentium Book Plus",
  "Halant",
  "IBM Plex Sans",
  "LinLibertine",
  "Literata",
  "Lora",
  "Ubuntu"
];

Color backColor = Colors.white;
Color fontColor = Colors.black;
Color buttonBackgroundColor = const Color(0xFFEAEAEB);
Color buttonIconColor = const Color(0xFF252527);
int staticThemeId = 3;

class ShowEpub extends StatefulWidget {
  ShowEpub({
    super.key,
    required this.epubBook,
    required this.accentColor,
    required this.imageUrl,
    this.starterChapter = 0,
    this.shouldOpenDrawer = false,
    required this.bookId,
    required this.chapterListTitle,
    this.onPageFlip,
    this.onLastPage,
    this.starterPageInBook,
  });

  final Function(int currentPage, int totalPages)? onPageFlip;
  final Function(int lastPageIndex)? onLastPage;
  final Color accentColor;
  final String bookId;
  final String chapterListTitle;
  final EpubBook epubBook;
  final String imageUrl;
  final bool shouldOpenDrawer;
  final int starterChapter;
  final int? starterPageInBook;

  @override
  State<StatefulWidget> createState() => ShowEpubState();
}

class ShowEpubState extends State<ShowEpub> {
  int accumulatedPagesBeforeCurrentChapter = 0;
  bool allChaptersCalculated = false;
  late String bookId;
  String bookTitle = '';
  double brightnessLevel = 0.5;
  Map<int, int> chapterPageCounts = {};
  String chapterTitle = '';
  List<LocalChapterModel> chaptersList = [];
  final controller = ScrollController();
  PagingTextHandler controllerPaging = PagingTextHandler(paginate: () {}, bookId: '');
  TextDirection currentTextDirection = TextDirection.ltr;
  var dropDownFontItems;
  late EpubBook epubBook;
  double fontSizeProgress = 14.0;
  GetStorage gs = GetStorage();
  String htmlContent = '';
  String? innerHtmlContent;
  bool isCalculatingTotalPages = false;
  bool isLastPage = false;
  int lastSwipe = 0;
  Future<void> loadChapterFuture = Future.value(true);
  int prevSwipe = 0;
  late String selectedTextStyle;
  bool shouldOpenDrawer = false;
  bool showBrightnessWidget = false;
  bool showHeader = true;
  bool showNext = false;
  bool showPrevious = false;
  String textContent = '';
  int totalPagesInBook = 0;

  late EpubCacheHelper _cacheHelper;
  int _cachedKnownPagesTotal = 0;
  late EpubChapterHelper _chapterHelper;
  int _currentChapterPageCount = 0;
  String? _currentSubchapterTitle;
  Map<int, int> _filteredToOriginalIndex = {};
  double _fontSize = 14.0;
  bool _hasAppliedAudioSync = false;
  bool _isChangingTheme = false;
  bool _isLoadingChapter = false;
  bool _isProgressBarLongPressed = false;
  late EpubPaginationHelper _paginationHelper;
  int? _pendingCurrentPageInBook;
  int? _pendingTotalPages;
  int _preservedTotalPages = 0; // Preserved total during theme/font changes
  int? _targetChapterFromAudioSync;
  int? _targetPageFromAudioSync;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    isCalculatingTotalPages = false;
    super.dispose();
  }

  @override
  void initState() {
    loadThemeSettings();
    bookId = widget.bookId;
    epubBook = widget.epubBook;
    shouldOpenDrawer = widget.shouldOpenDrawer;
    controllerPaging = PagingTextHandler(paginate: () {}, bookId: bookId);

    selectedTextStyle = fontNames.firstWhere(
      (element) => element == selectedFont,
      orElse: () => fontNames.first,
    );

    _cacheHelper = EpubCacheHelper(bookId: bookId, gs: gs);
    _chapterHelper = EpubChapterHelper(
      epubBook: epubBook,
      bookId: bookId,
      bookProgress: bookProgress,
    );
    _paginationHelper = EpubPaginationHelper(
      epubBook: epubBook,
      fontSize: _fontSize,
      selectedTextStyle: selectedTextStyle,
      fontColor: fontColor,
    );

    _chapterHelper.initializeEpubStructure();

    getTitleFromXhtml();

    // TEMPORARILY clear cache to force recalculation with new pagination logic
    _cacheHelper.clearCache();
    _loadCachedPageCounts();

    reLoadChapter(init: true);

    super.initState();
  }

  loadThemeSettings() {
    selectedFont = gs.read(libFont) ?? selectedFont;
    var themeId = gs.read(libTheme) ?? staticThemeId;
    updateTheme(themeId, isInit: true);
    _fontSize = gs.read(libFontSize) ?? 14.0;
    fontSizeProgress = _fontSize;
  }

  getTitleFromXhtml() {
    if (epubBook.Title != null) {
      bookTitle = epubBook.Title!;
      updateUI();
    }
  }

  reLoadChapter({bool init = false, int index = -1, int startPage = 0}) async {
    if (_isLoadingChapter) return;
    _isLoadingChapter = true;
    int currentIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int targetIndex = index == -1 ? currentIndex : index;
    lastSwipe = 0;
    prevSwipe = 0;

    if (!init && index != -1 && index != currentIndex) {
      await bookProgress.setCurrentChapterIndex(bookId, index);
      await bookProgress.setCurrentPageIndex(bookId, startPage);
    } else if (startPage > 0) {
      await bookProgress.setCurrentPageIndex(bookId, startPage);
    }

    setState(() {
      loadChapterFuture = loadChapter(init: init, index: targetIndex).then((_) => _isLoadingChapter = false).catchError((e, _) => _isLoadingChapter = false);
    });
  }

  loadChapter({int index = -1, bool init = false}) async {
    final result = EpubChapterListBuilder.buildChaptersList(chapters: _chapters, epubBook: epubBook, chapterPageCounts: chapterPageCounts);
    chaptersList = result['chaptersList'] as List<LocalChapterModel>;
    _filteredToOriginalIndex = result['filteredToOriginalIndex'] as Map<int, int>;
    _updateChapterPageNumbers();
    // No background calculation - pages are calculated as chapters are read

    final progress = bookProgress.getBookProgress(bookId);
    final savedChapter = progress.currentChapterIndex ?? 0;
    final savedPage = progress.currentPageIndex ?? 0;
    final hasProgress = (savedChapter != 0) || (savedPage != 0);

    int targetIndex = index;
    if (init) {
      if (widget.starterPageInBook != null && chapterPageCounts.isNotEmpty) {
        final calcResult = _calculateChapterAndPageFromBookPage(widget.starterPageInBook!);
        if (calcResult != null) {
          targetIndex = calcResult['chapter']!;
          _targetChapterFromAudioSync = calcResult['chapter'];
          _targetPageFromAudioSync = calcResult['page'];
        } else {
          targetIndex = hasProgress ? savedChapter : 0;
        }
      } else if (hasProgress) {
        targetIndex = savedChapter;
      } else if (widget.starterChapter >= 0 && widget.starterChapter < chaptersList.length) {
        targetIndex = widget.starterChapter;
      } else {
        targetIndex = 0;
      }
    }
    if (targetIndex < 0 || targetIndex >= chaptersList.length) targetIndex = 0;
    setupNavButtons();
    await updateContentAccordingChapter(targetIndex);
  }

  updateContentAccordingChapter(int chapterIndex) async {
    print('📖 updateContentAccordingChapter: chapterIndex=$chapterIndex');
    final currentSavedIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    if (currentSavedIndex != chapterIndex) {
      await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
    }
    print('   chapterPageCounts: $chapterPageCounts');
    print('   _filteredToOriginalIndex: $_filteredToOriginalIndex');

    // Use helper to load chapter content
    final result = EpubContentHelper.loadChapterContent(
      chapters: _chapters,
      chapterIndex: chapterIndex,
      filteredToOriginalIndex: _filteredToOriginalIndex,
      chapterPageCounts: chapterPageCounts,
      chaptersList: chaptersList,
      bookId: bookId,
      allChaptersCalculated: allChaptersCalculated,
      totalPagesInBook: totalPagesInBook,
      epubBook: epubBook,
    );

    htmlContent = result['htmlContent'];
    innerHtmlContent = htmlContent;
    textContent = result['textContent'];
    currentTextDirection = result['textDirection'];
    accumulatedPagesBeforeCurrentChapter = result['accumulatedPagesBeforeCurrentChapter'];

    final currentPageInBook = result['currentPageInBook'] as int;
    final displayTotalPages = result['displayTotalPages'] as int;

    // Don't override pending values if already set (e.g., during theme change)
    if (_pendingCurrentPageInBook == null) {
      _pendingCurrentPageInBook = currentPageInBook;
    }
    if (_pendingTotalPages == null) {
      _pendingTotalPages = displayTotalPages;
    }

    controllerPaging.currentPage.value = _pendingCurrentPageInBook ?? currentPageInBook;
    controllerPaging.totalPages.value = _pendingTotalPages ?? displayTotalPages;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controllerPaging.currentPage.value = _pendingCurrentPageInBook ?? currentPageInBook;
      controllerPaging.totalPages.value = _pendingTotalPages ?? displayTotalPages;
    });

    setupNavButtons();
  }

  bool isHTML(String str) => EpubContentHelper.isHTML(str);

  setupNavButtons() {
    int index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    setState(() {
      showPrevious = index > 0;
      showNext = index < chaptersList.length - 1;
    });
  }

  Future<bool> backPress() async => true;

  void _clearPageCountsCache() {
    // Save current total from controller (most accurate source) before clearing
    final oldTotal = controllerPaging.totalPages.value > 0 ? controllerPaging.totalPages.value : (totalPagesInBook > 0 ? totalPagesInBook : chapterPageCounts.values.fold(0, (s, c) => s + c));
    print('📦 Clearing cache - preserving oldTotal: $oldTotal');
    _preservedTotalPages = oldTotal; // Preserve for display during recalculation
    chapterPageCounts.clear();
    _cachedKnownPagesTotal = 0;
    totalPagesInBook = oldTotal; // Keep old total until fully recalculated
    allChaptersCalculated = false;
    _currentChapterPageCount = 0;
    accumulatedPagesBeforeCurrentChapter = 0;
    gs.remove('book_${bookId}_page_counts');
  }

  void changeFontSize(double newSize) {
    fontSizeProgress = newSize;
    _fontSize = newSize;
    gs.write(libFontSize, _fontSize);
    _clearPageCountsCache();
    final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final currentPageIdx = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
    setState(() {});
    reLoadChapter(index: currentChapterIdx, startPage: currentPageIdx);
  }

  openTableOfContents() async {
    final originalChapterIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final currentPageInBook = controllerPaging.currentPage.value;

    // Calculate total pages in book from chapterPageCounts
    final bookTotalPages = totalPagesInBook > 0 ? totalPagesInBook : chapterPageCounts.values.fold(0, (sum, count) => sum + count);

    final result = await EpubTocHelper.showTocBottomSheet(
      context: context,
      bookTitle: bookTitle,
      bookId: bookId,
      imageUrl: widget.imageUrl,
      chapters: chaptersList,
      accentColor: widget.accentColor,
      chapterListTitle: widget.chapterListTitle,
      currentPage: currentPageInBook,
      totalPages: bookTotalPages,
      currentPageInChapter: currentPageInBook, // Show page in book, not in chapter
      currentSubchapterTitle: _currentSubchapterTitle,
      isCalculating: !allChaptersCalculated,
    );
    if (result == null) return;

    await EpubTocHelper.handleTocSelection(
      result: result,
      bookId: bookId,
      originalChapterIndex: originalChapterIndex,
      chaptersList: chaptersList,
      filteredToOriginalIndex: _filteredToOriginalIndex,
      calculateChapterAndPage: _calculateChapterAndPageFromBookPage,
      reloadChapter: (index, startPage) async => reLoadChapter(index: index, startPage: startPage),
      setCurrentSubchapterTitle: (title) => _currentSubchapterTitle = title,
    );
  }

  void setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
    await Future.delayed(const Duration(seconds: 2));
    showBrightnessWidget = false;
    updateUI();
  }

  Widget buildThemeCard({
    required BuildContext context,
    required int id,
    required String title,
    required Color backgroundColor,
    required Color textColor,
    required bool isSelected,
    required StateSetter setState,
  }) =>
      EpubThemeHelper.buildThemeCard(
        id: id,
        title: title,
        backgroundColor: backgroundColor,
        textColor: textColor,
        isSelected: isSelected,
        accentColor: widget.accentColor,
        onTap: () {
          updateTheme(id);
          setState(() {});
        },
      );

  updateTheme(int id, {bool isInit = false, bool? forceDarkMode}) {
    staticThemeId = id;
    final themeConfig = EpubThemeHelper.getThemeConfig(id, forceDarkMode: forceDarkMode);
    backColor = themeConfig.backColor;
    fontColor = themeConfig.fontColor;
    buttonBackgroundColor = themeConfig.buttonBackgroundColor;
    buttonIconColor = themeConfig.buttonIconColor;
    selectedFont = themeConfig.selectedFont;
    selectedTextStyle = themeConfig.selectedTextStyle;
    gs.write(libTheme, id);
    gs.write(libFont, selectedFont);

    if (!isInit) {
      print('🎨 THEME CHANGE START');
      print('   Current chapter: ${bookProgress.getBookProgress(bookId).currentChapterIndex}');
      print('   Current page: ${bookProgress.getBookProgress(bookId).currentPageIndex}');
      print('   controllerPaging.currentPage: ${controllerPaging.currentPage.value}');
      print('   controllerPaging.totalPages: ${controllerPaging.totalPages.value}');

      // Preserve book-wide page before clearing cache
      final bookWideCurrentPage = controllerPaging.currentPage.value;

      Navigator.of(context).pop();
      _clearPageCountsCache();
      print('   Cache cleared. chapterPageCounts: ${chapterPageCounts.length}');
      setState(() => _isChangingTheme = true);
      final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
      final currentPageIdx = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;

      // Set pending to restore book-wide page after reload
      _pendingCurrentPageInBook = bookWideCurrentPage;

      reLoadChapter(index: currentChapterIdx, startPage: currentPageIdx).then((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        print('🎨 THEME CHANGE COMPLETE');
        print('   controllerPaging.currentPage: ${controllerPaging.currentPage.value}');
        print('   controllerPaging.totalPages: ${controllerPaging.totalPages.value}');
        print('   chapterPageCounts: ${chapterPageCounts.length} chapters');
        if (mounted) setState(() => _isChangingTheme = false);
      });
    }
    updateUI();
  }

  updateUI() => setState(() {});

  /// Handle page flip callback from PagingWidget
  Future<void> _handlePageFlip(int currentPage, int totalPages) async {
    var currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    var originalChapterIdx = _filteredToOriginalIndex[currentChapterIdx] ?? currentChapterIdx;
    _currentChapterPageCount = totalPages;

    // Update cache with REAL page count from pagination
    int oldPageCount = chapterPageCounts[originalChapterIdx] ?? 0;
    if (oldPageCount != totalPages) {
      int diff = totalPages - oldPageCount;
      chapterPageCounts[originalChapterIdx] = totalPages;
      _cachedKnownPagesTotal += diff;
      // During recalculation, don't set totalPagesInBook lower than preserved value
      if (_preservedTotalPages > 0 && _cachedKnownPagesTotal < _preservedTotalPages && !allChaptersCalculated) {
        // Keep preserved total during partial recalculation
        totalPagesInBook = _preservedTotalPages;
      } else {
        totalPagesInBook = _cachedKnownPagesTotal;
        // Clear preserved when we have calculated all or exceeded it
        if (allChaptersCalculated) _preservedTotalPages = 0;
      }

      // Check if all chapters are now calculated
      if (chapterPageCounts.length == _chapters.length) {
        allChaptersCalculated = true;
      }

      _saveCachedPageCounts();
      _updateChapterPageNumbers();
    }

    // Calculate current page in book
    int accumulatedBefore = 0;
    for (int i = 0; i < originalChapterIdx; i++) {
      accumulatedBefore += chapterPageCounts[i] ?? 0;
    }
    int currentPageInBook = accumulatedBefore + currentPage + 1;

    final effectiveCurrentPage = _pendingCurrentPageInBook ?? currentPageInBook;

    // Update controller values
    if (!_isChangingTheme) {
      controllerPaging.currentPage.value = effectiveCurrentPage;
      // Use preserved total if still recalculating
      final displayTotal = (_preservedTotalPages > 0 && !allChaptersCalculated) ? _preservedTotalPages : totalPagesInBook;
      controllerPaging.totalPages.value = displayTotal;
    }

    _updateSubchapterTitleForPage(currentChapterIdx, currentPage);
    widget.onPageFlip?.call(currentPageInBook, totalPagesInBook);
    bookProgress.setCurrentPageIndex(bookId, currentPage == totalPages - 1 ? 0 : currentPage);

    isLastPage ? showHeader = true : lastSwipe = 0;
    isLastPage = false;
    updateUI();

    // Handle swipe to previous chapter
    if (currentPage == 0 && totalPages > 1) {
      prevSwipe++;
      lastSwipe = 0;
      if (prevSwipe > 1 && !_isLoadingChapter) {
        var idx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
        if (idx > 0) {
          final prevOrigIdx = _filteredToOriginalIndex[idx - 1];
          int lastPage = (prevOrigIdx != null && chapterPageCounts.containsKey(prevOrigIdx)) ? chapterPageCounts[prevOrigIdx]! - 1 : 0;
          await bookProgress.setCurrentPageIndex(bookId, lastPage);
          prevChapter();
        }
      }
    } else {
      prevSwipe = 0;
    }
  }

  /// Handle last page callback from PagingWidget
  Future<void> _handleLastPage(int index, int totalPages) async {
    print('📄 _handleLastPage called: index=$index, totalPages=$totalPages, lastSwipe=$lastSwipe');
    print('   ⏰ Timestamp: ${DateTime.now().millisecondsSinceEpoch}');
    widget.onLastPage?.call(index);
    if (!_isLoadingChapter) {
      lastSwipe = totalPages > 1 ? lastSwipe + 1 : 2;
      prevSwipe = 0;
      print('   lastSwipe incremented to: $lastSwipe');
      // Need 2 swipes to change chapter
      if (lastSwipe > 1) {
        print('   ⏳ Starting animation wait (450ms)');
        print('   ⏰ Wait start time: ${DateTime.now().millisecondsSinceEpoch}');
        // Wait for page flip animation to complete
        await Future.delayed(const Duration(milliseconds: 450));
        print('   ✅ Animation wait completed!');
        print('   ⏰ Wait end time: ${DateTime.now().millisecondsSinceEpoch}');
        print('   🔄 NOW calling nextChapter()');
        nextChapter();
      }
    }
    isLastPage = true;
    updateUI();
  }

  nextChapter() async {
    print('🔄 nextChapter() CALLED');
    print('   ⏰ Timestamp: ${DateTime.now().millisecondsSinceEpoch}');
    if (_isLoadingChapter) return;
    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    lastSwipe = 0;
    prevSwipe = 0;

    if (index < chaptersList.length - 1) {
      _updateCacheBeforeChapterChange(index);
      await bookProgress.setCurrentPageIndex(bookId, 0);
      print('   📖 Calling reLoadChapter(index: ${index + 1})');
      reLoadChapter(index: index + 1);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('end_of_book'.tr), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
    }
  }

  prevChapter() async {
    if (_isLoadingChapter) return;
    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    lastSwipe = 0;
    prevSwipe = 0;

    if (index > 0) {
      _updateCacheBeforeChapterChange(index);
      final currentPageIndex = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
      reLoadChapter(index: index - 1, startPage: currentPageIndex);
    }
  }

  void _updateCacheBeforeChapterChange(int index) {
    var originalIdx = _filteredToOriginalIndex[index] ?? index;
    var currentTotal = _currentChapterPageCount;
    if (!allChaptersCalculated && currentTotal > 0 && chapterPageCounts[originalIdx] != currentTotal) {
      int oldCount = chapterPageCounts[originalIdx] ?? 0;
      chapterPageCounts[originalIdx] = currentTotal;
      _cachedKnownPagesTotal = _cachedKnownPagesTotal - oldCount + currentTotal;
      totalPagesInBook = _cachedKnownPagesTotal;
      _saveCachedPageCounts();
      _updateChapterPageNumbers();
    }
  }

  String _getChapterTitleForDisplay(int currentChapterIndex) {
    return _chapterHelper.getChapterTitleForDisplay(
      currentChapterIndex: currentChapterIndex,
      chaptersList: chaptersList,
      currentSubchapterTitle: _currentSubchapterTitle,
    );
  }

  void _updateSubchapterTitleForPage(int currentChapterIndex, int pageInChapter) {
    _currentSubchapterTitle = _chapterHelper.updateSubchapterTitleForPage(
      currentChapterIndex: currentChapterIndex,
      pageInChapter: pageInChapter,
      chaptersList: chaptersList,
    );
  }

  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];

  Map<String, int>? _calculateChapterAndPageFromBookPage(int targetPageInBook) {
    return _paginationHelper.calculateChapterAndPageFromBookPage(
      targetPageInBook,
      chapterPageCounts,
    );
  }

  void _loadCachedPageCounts() {
    chapterPageCounts = _cacheHelper.loadCachedPageCounts(
      _chapters.length,
      fontSize: _fontSize,
      themeId: staticThemeId,
    );
    // Calculate total from whatever we have cached
    _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
    totalPagesInBook = _cachedKnownPagesTotal;
    allChaptersCalculated = chapterPageCounts.length == _chapters.length;

    // If we have complete cache, use it
    if (allChaptersCalculated && totalPagesInBook > 0) {
      controllerPaging.totalPages.value = totalPagesInBook;
    } else {
      // Start background calculation for missing chapters
      _startBackgroundCalculation();
    }
  }

  void _startBackgroundCalculation() async {
    if (!mounted) return;

    final results = await EpubBackgroundCalculator.calculateAllChaptersInBackground(
      chapters: _chapters,
      fontSize: _fontSize,
      existingPageCounts: chapterPageCounts,
      onChapterCalculated: (chapterIndex, pages) {
        if (!mounted) return;
        // Only update if not already calculated with real pagination
        if (!chapterPageCounts.containsKey(chapterIndex)) {
          chapterPageCounts[chapterIndex] = pages;
          _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
          totalPagesInBook = _cachedKnownPagesTotal;
          _updateChapterPageNumbers();
        }
      },
      shouldContinue: () => mounted,
      verbose: false,
    );

    if (!mounted) return;

    // Update all calculated values
    for (var entry in results.entries) {
      if (!chapterPageCounts.containsKey(entry.key)) {
        chapterPageCounts[entry.key] = entry.value;
      }
    }

    _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
    totalPagesInBook = _cachedKnownPagesTotal;
    allChaptersCalculated = chapterPageCounts.length == _chapters.length;

    if (allChaptersCalculated) {
      controllerPaging.totalPages.value = totalPagesInBook;
      _saveCachedPageCounts();
    }

    _updateChapterPageNumbers();
  }

  void _saveCachedPageCounts() {
    _cacheHelper.saveCachedPageCounts(
      chapterPageCounts,
      fontSize: _fontSize,
      themeId: staticThemeId,
    );
  }

  void _updateChapterPageNumbers() {
    if (!mounted) return;

    _paginationHelper.updateChapterPageNumbers(
      chaptersList,
      chapterPageCounts,
      _filteredToOriginalIndex,
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(DESIGN_WIDTH, DESIGN_HEIGHT));
    return WillPopScope(
      onWillPop: backPress,
      child: Scaffold(
        backgroundColor: backColor,
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              Expanded(
                  child: Stack(children: [
                FutureBuilder<void>(future: loadChapterFuture, builder: (context, snapshot) => _buildChapterContent(snapshot)),
              ])),
            ]),
            _buildHeaderWidget(),
            _buildBottomNavWidget(),
          ]),
        ),
      ),
    );
  }

  /// Build chapter content based on FutureBuilder snapshot
  Widget _buildChapterContent(AsyncSnapshot<void> snapshot) {
    if (_isChangingTheme) return _buildLoadingWidget();
    if (snapshot.connectionState == ConnectionState.none || snapshot.connectionState == ConnectionState.waiting) return _buildLoadingWidget();
    if (snapshot.hasError) return _buildErrorWidget(snapshot.error);
    if (snapshot.connectionState == ConnectionState.done) {
      if (shouldOpenDrawer) {
        WidgetsBinding.instance.addPostFrameCallback((_) => openTableOfContents());
        shouldOpenDrawer = false;
      }
      return _buildPagingWidget();
    }
    return _buildLoadingWidget();
  }

  Widget _buildLoadingWidget() => Center(child: LoadingWidget(height: 100, animationWidth: 50, animationHeight: 50));

  Widget _buildErrorWidget(Object? error) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text('Error loading chapter', style: TextStyle(fontSize: 16, color: fontColor)),
          SizedBox(height: 8),
          Text('$error', style: TextStyle(fontSize: 12, color: fontColor.withOpacity(0.7)), textAlign: TextAlign.center),
        ]),
      );

  /// Build paging widget for chapter content
  Widget _buildPagingWidget() {
    var currentChapterIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int startPageIndex = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
    if (_targetChapterFromAudioSync == currentChapterIndex && _targetPageFromAudioSync != null && !_hasAppliedAudioSync) {
      startPageIndex = _targetPageFromAudioSync!;
      _hasAppliedAudioSync = true;
    }

    return PagingWidget(
      textContent,
      epubBook: epubBook,
      innerHtmlContent,
      lastWidget: null,
      starterPageIndex: startPageIndex,
      style: TextStyle(
          backgroundColor: backColor,
          fontSize: _fontSize.sp,
          fontFamily: selectedTextStyle,
          fontWeight: staticThemeId == 4 ? FontWeight.bold : FontWeight.w400,
          package: 'cosmos_epub',
          color: fontColor,
          height: 1.5,
          letterSpacing: 0.1),
      handlerCallback: _handlePagingCallback,
      onTextTap: () => setState(() => showHeader = !showHeader),
      onPageFlip: _handlePageFlip,
      onLastPage: _handleLastPage,
      chapterTitle: _getChapterTitleForDisplay(currentChapterIndex),
      totalChapters: chaptersList.length,
      bookId: bookId,
      showNavBar: showHeader,
    );
  }

  /// Handle paging controller callback
  void _handlePagingCallback(PagingTextHandler ctrl) {
    print('📊 _handlePagingCallback called');
    controllerPaging = ctrl;
    int calculatedTotal = chapterPageCounts.values.fold(0, (s, c) => s + c);
    print('   calculatedTotal from chapterPageCounts: $calculatedTotal');
    print('   chapterPageCounts.length: ${chapterPageCounts.length}');
    print('   allChaptersCalculated: $allChaptersCalculated');
    print('   totalPagesInBook: $totalPagesInBook');
    print('   _pendingTotalPages: $_pendingTotalPages');
    int bookTotal = _pendingTotalPages ?? (allChaptersCalculated ? totalPagesInBook : (calculatedTotal > 0 ? calculatedTotal : totalPagesInBook));
    print('   Final bookTotal: $bookTotal');
    print('   Current controllerPaging.totalPages: ${controllerPaging.totalPages.value}');

    // During recalculation, NEVER decrease total pages - only update when:
    // 1. All chapters calculated, OR
    // 2. New total is significantly higher (not just +/- a few pages from cache updates)
    // 3. First load (totalPages == 0)
    final currentTotal = controllerPaging.totalPages.value;

    // During recalculation, use preserved totalPagesInBook instead of partial calculation
    final displayTotal = allChaptersCalculated ? bookTotal : (totalPagesInBook > 0 ? totalPagesInBook : bookTotal);
    final shouldUpdate = allChaptersCalculated || currentTotal == 0 || (displayTotal > currentTotal && (displayTotal - currentTotal) > 5);

    if (shouldUpdate) {
      controllerPaging.totalPages.value = displayTotal;
      print('   ✅ Updated totalPages to: $displayTotal');
    } else {
      print('   ⏸️ Keeping previous totalPages: $currentTotal (bookTotal: $bookTotal, displayTotal: $displayTotal, diff: ${displayTotal - currentTotal})');
    }

    if (_pendingCurrentPageInBook != null) {
      print('   Setting currentPage to: $_pendingCurrentPageInBook');
      controllerPaging.currentPage.value = _pendingCurrentPageInBook!;
      _pendingCurrentPageInBook = null;
    }
    if (_pendingTotalPages != null) _pendingTotalPages = null;
  }

  /// Build header widget
  Widget _buildHeaderWidget() => EpubHeaderWidget(
        showHeader: showHeader && !_isProgressBarLongPressed,
        fontColor: fontColor,
        backColor: backColor,
        bookTitle: bookTitle,
        bookImage: widget.imageUrl,
        bookId: bookId,
        onBackPressed: () => Navigator.pop(context),
        staticThemeId: staticThemeId,
        buttonBackgroundColor: buttonBackgroundColor,
        buttonIconColor: buttonIconColor,
      );

  /// Build bottom navigation widget
  Widget _buildBottomNavWidget() {
    final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final currentChapterTitle = currentChapterIdx >= 0 && currentChapterIdx < chaptersList.length ? chaptersList[currentChapterIdx].chapter : '';
    final originalChapterIdx = _filteredToOriginalIndex[currentChapterIdx] ?? currentChapterIdx;
    final isCurrentChapterCalculated = chapterPageCounts.containsKey(originalChapterIdx);
    print('📱 _buildBottomNavWidget - currentPage: ${controllerPaging.currentPage.value}, totalPages: ${controllerPaging.totalPages.value}, isCalculating: ${!isCurrentChapterCalculated}');
    return Obx(() => EpubBottomNavWidget(
          showHeader: showHeader,
          fontColor: fontColor,
          backColor: backColor,
          currentPage: controllerPaging.currentPage.value,
          totalPages: controllerPaging.totalPages.value,
          isCalculating: !isCurrentChapterCalculated,
          chapterTitle: currentChapterTitle,
          onMenuPressed: openTableOfContents,
          onNextPage: () => controllerPaging.goToNextPage(),
          onPreviousPage: () => controllerPaging.goToPreviousPage(),
          onJumpToPage: (targetPageInBook) {
            final result = _calculateChapterAndPageFromBookPage(targetPageInBook);
            if (result != null) reLoadChapter(index: result['chapter']!, startPage: result['page']!);
          },
          onFontSettingsPressed: () {},
          fontSize: _fontSize,
          brightnessLevel: brightnessLevel,
          staticThemeId: staticThemeId,
          setBrightness: setBrightness,
          updateTheme: updateTheme,
          onFontSizeChange: changeFontSize,
          buttonBackgroundColor: buttonBackgroundColor,
          buttonIconColor: buttonIconColor,
          onProgressLongPressChanged: (isLongPressing) => setState(() => _isProgressBarLongPressed = isLongPressing),
        ));
  }
}
