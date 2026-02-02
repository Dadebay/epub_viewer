import 'package:cosmos_epub/helpers/pagination/paging_text_handler.dart';
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
int staticThemeId = 1;

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
  final RxBool allChaptersCalculated = false.obs;
  late String bookId;
  String bookTitle = '';
  double brightnessLevel = 0.5;
  Map<int, int> chapterPageCounts = {};
  final Map<int, Map<String, int>> _subchapterPageMapByChapter = {};
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
  bool _isSubchapterTitleLocked = false; // Lock subchapter title when navigating via TOC
  bool _isInitialPageLoad = false; // Track if this is the first page load after TOC navigation
  Map<int, int> _filteredToOriginalIndex = {};
  double _fontSize = 14.0;
  bool _hasAppliedAudioSync = false;
  bool _isChangingTheme = false;
  bool _isLoadingChapter = false;
  bool _isProgressBarLongPressed = false;
  bool _isBackgroundCalcRunning = false;
  late EpubPaginationHelper _paginationHelper;
  int? _pendingCurrentPageInBook;
  int? _pendingTotalPages;
  bool _isJumpLockActive = false;
  int? _jumpLockedOffsetInBook;
  int? _jumpLockedPageInBook;
  int? _jumpLockedTotalPages;
  int? _jumpLockedChapterIndex;
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
    final initStartTime = DateTime.now();
    print('⏱️ [TIMING] initState START at ${initStartTime.toIso8601String()}');

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

    // Hyphenation aktif (soft hyphen ile satır sonu tire)

    getTitleFromXhtml();

    // Initialize pagination and load - cache will be used if valid
    // _cacheHelper.clearCache(); // Removed to use cache

    final beforeInitPagination = DateTime.now();
    print('⏱️ [TIMING] Starting _initializePaginationAndLoad at ${beforeInitPagination.toIso8601String()}');
    _initializePaginationAndLoad();

    super.initState();

    final initEndTime = DateTime.now();
    final totalInitTime = initEndTime.difference(initStartTime).inMilliseconds;
    print('⏱️ [TIMING] initState COMPLETE - Total time: ${totalInitTime}ms');
  }

  Future<void> _initializePaginationAndLoad() async {
    final startTime = DateTime.now();
    print('⏱️ [TIMING] _initializePaginationAndLoad START');

    final cacheLoadStart = DateTime.now();
    _loadCachedPageCounts();
    final cacheLoadEnd = DateTime.now();
    print('⏱️ [TIMING] Cache loading took: ${cacheLoadEnd.difference(cacheLoadStart).inMilliseconds}ms');
    print('📊 [TIMING] Cached chapters: ${chapterPageCounts.length}/${_chapters.length}');

    // Load the chapter immediately - don't wait for all chapters to be calculated
    if (mounted) {
      final reloadStart = DateTime.now();
      print('⏱️ [TIMING] Starting reLoadChapter (Immediate Load)...');
      reLoadChapter(init: true);
      final reloadEnd = DateTime.now();
      print('⏱️ [TIMING] reLoadChapter took: ${reloadEnd.difference(reloadStart).inMilliseconds}ms');
    }

    if (!allChaptersCalculated.value) {
      // Start background calculation WITHOUT await
      // This allows the UI to remain responsive and show the book immediately

      // Give the UI a shorter delay to render the first chapter before starting heavy calculation
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !allChaptersCalculated.value) {
          print('⏱️ [TIMING] Starting _precalculateAllChaptersBlocking (BACKGROUND) for ${_chapters.length} chapters...');
          _precalculateAllChaptersBlocking().then((_) {
            print('⏱️ [TIMING] Background calculation finished');
          });
        }
      });
    } else {
      print('✅ [TIMING] All chapters already calculated from cache!');
    }

    final endTime = DateTime.now();
    final totalDuration = endTime.difference(startTime).inMilliseconds;
    print('⏱️ [TIMING] _initializePaginationAndLoad TOTAL (UI Unblocked): ${totalDuration}ms (${(totalDuration / 1000).toStringAsFixed(2)}s)');
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
      // Don't call updateUI() here - it will be called later in loadChapter
    }
  }

  reLoadChapter({bool init = false, int index = -1, int startPage = -1}) async {
    if (_isLoadingChapter) return;
    _isLoadingChapter = true;
    int currentIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int targetIndex = index == -1 ? currentIndex : index;
    lastSwipe = 0;
    prevSwipe = 0;

    if (!init && index != -1 && index != currentIndex) {
      // Different chapter - update both chapter and page
      await bookProgress.setCurrentChapterIndex(bookId, index);
      await bookProgress.setCurrentPageIndex(bookId, startPage >= 0 ? startPage : 0);
    } else if (startPage >= 0) {
      // Same chapter but specific page requested - update page
      await bookProgress.setCurrentPageIndex(bookId, startPage);
    }
    final isCalculatingUi = isCalculatingTotalPages;
    setState(() {
      loadChapterFuture = loadChapter(init: init, index: targetIndex).then((_) => _isLoadingChapter = false).catchError((e, _) => _isLoadingChapter = false);
    });
  }

  loadChapter({int index = -1, bool init = false}) async {
    // Only rebuild chapters list if it's empty or if it's the initial load
    // This avoids expensive rebuilds on every chapter navigation
    if (chaptersList.isEmpty || init) {
      final result = EpubChapterListBuilder.buildChaptersList(chapters: _chapters, epubBook: epubBook, chapterPageCounts: chapterPageCounts);
      chaptersList = result['chaptersList'] as List<LocalChapterModel>;
      _filteredToOriginalIndex = result['filteredToOriginalIndex'] as Map<int, int>;
      _updateChapterPageNumbers();
    }

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
    final currentSavedIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    if (currentSavedIndex != chapterIndex) {
      await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
    }
    final result = EpubContentHelper.loadChapterContent(
      chapters: _chapters,
      chapterIndex: chapterIndex,
      filteredToOriginalIndex: _filteredToOriginalIndex,
      chapterPageCounts: chapterPageCounts,
      chaptersList: chaptersList,
      bookId: bookId,
      allChaptersCalculated: allChaptersCalculated.value,
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
    _preservedTotalPages = oldTotal; // Preserve for display during recalculation
    // Keep existing counts as a fallback so TOC can still show start pages
    // but mark them as stale until recalculated.
    _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (s, c) => s + c);
    totalPagesInBook = oldTotal; // Keep old total until fully recalculated
    allChaptersCalculated.value = false;
    isCalculatingTotalPages = true;
    _currentChapterPageCount = 0;
    accumulatedPagesBeforeCurrentChapter = 0;
    gs.remove('book_${bookId}_page_counts');

    // Kick off REAL pagination calculation so loading can finish
    _startRealPaginationCalculation();
  }

  void changeFontSize(double newSize) {
    fontSizeProgress = newSize;
    _fontSize = newSize;
    gs.write(libFontSize, _fontSize);

    // CRITICAL: Clear cache and force full repagination
    _clearPageCountsCache();

    // Get current position BEFORE repagination
    final currentPageInBook = controllerPaging.currentPage.value;
    final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    // Calculate chapter-relative page from book page
    int accumulatedPages = 0;
    final originalChapterIdx = _filteredToOriginalIndex[currentChapterIdx] ?? currentChapterIdx;

    for (int i = 0; i < originalChapterIdx; i++) {
      accumulatedPages += chapterPageCounts[i] ?? 0;
    }

    int pageInChapter = (currentPageInBook - accumulatedPages - 1).clamp(0, (chapterPageCounts[originalChapterIdx] ?? 1) - 1);

    // Lock to preserve position during repagination
    _setJumpLock(
      pageInBook: currentPageInBook,
      totalPages: totalPagesInBook,
      chapterIndex: currentChapterIdx,
      pageInChapter: pageInChapter,
    );

    setState(() {});

    // Reload with preserved position
    reLoadChapter(index: currentChapterIdx, startPage: pageInChapter);
  }
  // void changeFontSize(double newSize) {
  //   fontSizeProgress = newSize;
  //   _fontSize = newSize;
  //   gs.write(libFontSize, _fontSize);
  //   _clearPageCountsCache();
  //   final currentChapterIdx =
  //       bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
  //   final currentPageIdx =
  //       bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
  //   setState(() {});
  //   reLoadChapter(index: currentChapterIdx, startPage: currentPageIdx);
  // }

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
      chapterPageCounts: chapterPageCounts,
      subchapterPageMapByChapter: _subchapterPageMapByChapter,
      filteredToOriginalIndex: _filteredToOriginalIndex,
      accentColor: widget.accentColor,
      chapterListTitle: widget.chapterListTitle,
      currentPage: currentPageInBook,
      totalPages: bookTotalPages,
      currentPageInChapter: currentPageInBook, // Show page in book, not in chapter
      currentSubchapterTitle: _currentSubchapterTitle,
      isCalculating: isCalculatingTotalPages,
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
      setCurrentSubchapterTitle: (title) {
        _currentSubchapterTitle = title;
        // TOC'dan subchapter seçildiğinde lock'ı aktif et
        _isSubchapterTitleLocked = title != null;
        _isInitialPageLoad = title != null; // Mark as initial load if going to subchapter
      },
    );
  }

  void setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
    // Reduced delay from 2s to 0.5s for faster UI response
    await Future.delayed(const Duration(milliseconds: 500));
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
      final bookWideCurrentPage = controllerPaging.currentPage.value;

      Navigator.of(context).pop();
      _clearPageCountsCache();
      setState(() => _isChangingTheme = true);
      final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
      final currentPageIdx = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;

      // Set pending to restore book-wide page after reload
      _pendingCurrentPageInBook = bookWideCurrentPage;

      reLoadChapter(index: currentChapterIdx, startPage: currentPageIdx).then((_) async {
        // Reduced delay from 100ms to 50ms for faster UI response
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) setState(() => _isChangingTheme = false);
      });
    }
    updateUI();
  }

  updateUI() => setState(() {});

  void _setJumpLock({
    required int pageInBook,
    required int totalPages,
    required int chapterIndex,
    required int pageInChapter,
  }) {
    _isJumpLockActive = true;
    _jumpLockedOffsetInBook = pageInBook - pageInChapter;
    _jumpLockedPageInBook = pageInBook;
    _jumpLockedTotalPages = totalPages;
    _jumpLockedChapterIndex = chapterIndex;
    _pendingCurrentPageInBook = pageInBook;
    _pendingTotalPages = totalPages;
  }

  int _originalToFilteredIndex(int originalChapterIdx) {
    for (final entry in _filteredToOriginalIndex.entries) {
      if (entry.value == originalChapterIdx && !chaptersList[entry.key].isSubChapter) {
        return entry.key;
      }
    }
    return originalChapterIdx;
  }

  int _findNextMainChapterIndex(int fromIndex) {
    for (int i = fromIndex + 1; i < chaptersList.length; i++) {
      if (!chaptersList[i].isSubChapter) return i;
    }
    return -1;
  }

  int _findPrevMainChapterIndex(int fromIndex) {
    for (int i = fromIndex - 1; i >= 0; i--) {
      if (!chaptersList[i].isSubChapter) return i;
    }
    return -1;
  }

  void _clearJumpLock() {
    _isJumpLockActive = false;
    _jumpLockedOffsetInBook = null;
    _jumpLockedPageInBook = null;
    _jumpLockedTotalPages = null;
    _jumpLockedChapterIndex = null;
    _pendingCurrentPageInBook = null;
    _pendingTotalPages = null;
  }

  /// Handle page flip callback from PagingWidget
  Future<void> _handlePageFlip(int currentPage, int totalPages) async {
    var currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    var originalChapterIdx = _filteredToOriginalIndex[currentChapterIdx] ?? currentChapterIdx;

    _currentChapterPageCount = totalPages;

    if (_isJumpLockActive) {
      if (_jumpLockedChapterIndex != currentChapterIdx) {
        _clearJumpLock();
      }
    }

    // Update cache with REAL page count from pagination
    // But DON'T update totalPagesInBook after initial calculation to keep it stable
    int oldPageCount = chapterPageCounts[originalChapterIdx] ?? 0;
    if (oldPageCount != totalPages) {
      int diff = totalPages - oldPageCount;
      chapterPageCounts[originalChapterIdx] = totalPages;
      _cachedKnownPagesTotal += diff;

      // DEBUG: Chapter page count değişikliğini logla
      var chapterName = epubBook.Chapters != null && originalChapterIdx < epubBook.Chapters!.length ? epubBook.Chapters![originalChapterIdx].Title ?? 'Başlıksız' : 'Bilinmiyor';
      print('📄 Chapter $originalChapterIdx: $chapterName -> $totalPages sayfa (önceden: $oldPageCount)');
      print('   📊 Toplam: $_cachedKnownPagesTotal sayfa (${chapterPageCounts.length}/${_chapters.length} chapter hesaplandı)');

      // DEBUG: Tüm chapter page count'larını göster
      if (chapterPageCounts.length <= 15) {
        StringBuffer sb = StringBuffer('   📋 Chapter page counts: ');
        for (int i = 0; i < _chapters.length; i++) {
          var count = chapterPageCounts[i];
          if (count != null) {
            sb.write('[$i:$count] ');
          } else {
            sb.write('[$i:?] ');
          }
        }
        print(sb.toString());
      }

      // CRITICAL: Once all chapters are calculated, keep totalPagesInBook STABLE
      // Only update if we haven't finished initial calculation yet
      if (!allChaptersCalculated.value) {
        // During recalculation, don't set totalPagesInBook lower than preserved value
        if (_preservedTotalPages > 0 && _cachedKnownPagesTotal < _preservedTotalPages) {
          totalPagesInBook = _preservedTotalPages;
        } else {
          totalPagesInBook = _cachedKnownPagesTotal;
        }

        // Check if all chapters are now calculated
        if (chapterPageCounts.length == _chapters.length) {
          allChaptersCalculated.value = true;
          isCalculatingTotalPages = false;
          _preservedTotalPages = 0;
        }
      }
      // If already calculated, DON'T change totalPagesInBook - keep it stable for user

      _saveCachedPageCounts();
      _updateChapterPageNumbers();
    }

    // We have a valid page count for the current chapter, stop showing loading
    if (allChaptersCalculated.value) {
      isCalculatingTotalPages = false;
    }

    // Calculate current page in book
    int accumulatedBefore = 0;
    for (int i = 0; i < originalChapterIdx; i++) {
      accumulatedBefore += chapterPageCounts[i] ?? 0;
    }
    int currentPageInBook = accumulatedBefore + currentPage + 1;

    // DEBUG: Current page calculation
    print('📍 Current Page Calculation:');
    print('   Chapter Index: $originalChapterIdx, Page in Chapter: $currentPage');
    print('   Accumulated Before: $accumulatedBefore');
    print('   Current Page in Book: $currentPageInBook / $totalPagesInBook');

    if (_isJumpLockActive && _jumpLockedChapterIndex == currentChapterIdx && _jumpLockedOffsetInBook != null) {
      currentPageInBook = _jumpLockedOffsetInBook! + currentPage + 1;
    }

    final effectiveCurrentPage = _isJumpLockActive ? (_jumpLockedPageInBook ?? _pendingCurrentPageInBook ?? currentPageInBook) : (_pendingCurrentPageInBook ?? currentPageInBook);

    // Update controller values
    if (!_isChangingTheme) {
      controllerPaging.currentPage.value = effectiveCurrentPage;
      // Use locked total (during jump) or pending total; keep preserved total during recalculation
      final preservedTotal = _preservedTotalPages > 0 ? _preservedTotalPages : null;
      final displayTotal = _isJumpLockActive
          ? (_jumpLockedTotalPages ??
              _pendingTotalPages ??
              (isCalculatingTotalPages ? (preservedTotal ?? totalPagesInBook) : ((_preservedTotalPages > 0 && !allChaptersCalculated.value) ? _preservedTotalPages : totalPagesInBook)))
          : (_pendingTotalPages ??
              (isCalculatingTotalPages ? (preservedTotal ?? totalPagesInBook) : ((_preservedTotalPages > 0 && !allChaptersCalculated.value) ? _preservedTotalPages : totalPagesInBook)));
      controllerPaging.totalPages.value = displayTotal;
    }

    _updateSubchapterTitleForPage(currentChapterIdx, currentPage);
    widget.onPageFlip?.call(currentPageInBook, totalPagesInBook);
    bookProgress.setCurrentPageIndex(bookId, currentPage);

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
    widget.onLastPage?.call(index);
    if (!_isLoadingChapter) {
      lastSwipe = totalPages > 1 ? lastSwipe + 1 : 2;
      prevSwipe = 0;
      // Need 2 swipes to change chapter
      if (lastSwipe > 1) {
        // Don't wait - let the animation complete naturally with content already loaded
        nextChapter();
      }
    }
    isLastPage = true;
    updateUI();
  }

  nextChapter() async {
    if (_isLoadingChapter) return;
    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    lastSwipe = 0;
    prevSwipe = 0;
    // Unlock subchapter title when changing chapters
    _isSubchapterTitleLocked = false;
    _currentSubchapterTitle = null;

    final nextChapterIdx = _findNextMainChapterIndex(index);
    if (nextChapterIdx != -1) {
      _updateCacheBeforeChapterChange(index);

      // Calculate the correct page in book for the new chapter's first page
      final nextOriginalIdx = _filteredToOriginalIndex[nextChapterIdx] ?? nextChapterIdx;
      int accumulatedBefore = 0;
      for (int i = 0; i < nextOriginalIdx; i++) {
        accumulatedBefore += chapterPageCounts[i] ?? 0;
      }
      final nextChapterFirstPage = accumulatedBefore + 1; // First page of next chapter

      print('➡️ nextChapter: Going to chapter $nextChapterIdx, first page in book: $nextChapterFirstPage');

      // Set pending page BEFORE reloading to preserve correct position
      _pendingCurrentPageInBook = nextChapterFirstPage;

      await bookProgress.setCurrentPageIndex(bookId, 0);
      reLoadChapter(index: nextChapterIdx);
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
    // Unlock subchapter title when changing chapters
    _isSubchapterTitleLocked = false;
    _currentSubchapterTitle = null;

    final prevChapterIdx = _findPrevMainChapterIndex(index);
    if (prevChapterIdx != -1) {
      _updateCacheBeforeChapterChange(index);
      final currentPageIndex = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
      reLoadChapter(index: prevChapterIdx, startPage: currentPageIndex);
    }
  }

  void _updateCacheBeforeChapterChange(int index) {
    var originalIdx = _filteredToOriginalIndex[index] ?? index;
    var currentTotal = _currentChapterPageCount;
    if (!allChaptersCalculated.value && currentTotal > 0 && chapterPageCounts[originalIdx] != currentTotal) {
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

  /// Get the parent chapter title for pagination parsing
  /// This should NEVER return the subchapter title, only the main chapter title
  String _getParentChapterTitleForParsing(int currentChapterIndex) {
    if (currentChapterIndex < 0 || currentChapterIndex >= chaptersList.length) {
      return '';
    }
    // Always return the main chapter title, never the subchapter
    return chaptersList[currentChapterIndex].chapter;
  }

  void _updateSubchapterTitleForPage(int currentChapterIndex, int pageInChapter) {
    print('🔎 _updateSubchapterTitleForPage called: chapterIdx=$currentChapterIndex, pageInChapter=$pageInChapter');

    // If subchapter title is locked (from TOC navigation)
    if (_isSubchapterTitleLocked && _currentSubchapterTitle != null) {
      // If this is the initial page load, keep the lock and skip detection
      if (_isInitialPageLoad) {
        print('🔒 Subchapter locked (initial load): "${_currentSubchapterTitle}" (pageInChapter: $pageInChapter)');
        _isInitialPageLoad = false; // Clear flag after first callback
        return;
      }

      // After initial load, release lock to allow natural subchapter detection
      print('🔓 Releasing subchapter lock after initial load');
      _isSubchapterTitleLocked = false;
    }

    // Get the original chapter index for accessing the subchapter map
    final originalChapterIndex = _filteredToOriginalIndex[currentChapterIndex] ?? currentChapterIndex;

    // Use the actual paginated subchapter map instead of LocalChapterModel pageInChapter
    final subchapterMap = _subchapterPageMapByChapter[originalChapterIndex];

    // Detect subchapter based on current page using the actual pagination data
    final detectedSubchapter = _chapterHelper.updateSubchapterTitleForPageWithMap(
      currentChapterIndex: currentChapterIndex,
      pageInChapter: pageInChapter,
      chaptersList: chaptersList,
      subchapterPageMap: subchapterMap,
    );

    print('🔎 Detected subchapter: "$detectedSubchapter" (current: "$_currentSubchapterTitle")');

    if (detectedSubchapter == null) {
      print('🚨 Subchapter is null at chapter $currentChapterIndex, page $pageInChapter. Skipping auto-advance.');
      if (_currentSubchapterTitle != null) {
        _currentSubchapterTitle = null;
        setState(() {}); // Clear subchapter title display when none detected
      }
      return;
    }

    if (_currentSubchapterTitle != detectedSubchapter) {
      print('🔄 Subchapter changed: "${_currentSubchapterTitle}" -> "$detectedSubchapter" (page: $pageInChapter)');
      _currentSubchapterTitle = detectedSubchapter;
      setState(() {}); // Force UI rebuild when subchapter changes
    }
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
    allChaptersCalculated.value = chapterPageCounts.length == _chapters.length;
    isCalculatingTotalPages = !allChaptersCalculated.value;

    // If we have complete cache, use it
    if (allChaptersCalculated.value && totalPagesInBook > 0) {
      controllerPaging.totalPages.value = totalPagesInBook;
    } else {
      // Start REAL pagination calculation for all chapters (not estimation)
      _startRealPaginationCalculation();
    }
  }

  void _startRealPaginationCalculation() {
    if (_isBackgroundCalcRunning) return;

    // Use addPostFrameCallback to ensure we have the correct screen dimensions
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_isBackgroundCalcRunning) return;

      _isBackgroundCalcRunning = true;
      isCalculatingTotalPages = true;
      if (mounted) setState(() {});

      // Get actual page size from screen dimensions
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final pageSize = Size(screenWidth, screenHeight);

      // Calculate priority: Current -> End, then Previous -> 0
      final currentIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
      List<int> priorityList = [];
      for (int i = currentIdx; i < _chapters.length; i++) priorityList.add(i);
      for (int i = currentIdx - 1; i >= 0; i--) priorityList.add(i);

      final results = await _paginationHelper.precalculateAllChapters(
        priorityList: priorityList,
        existingPageCounts: chapterPageCounts,
        pageSize: pageSize,
        onChapterCalculated: (chapterIndex, pages) {
          if (!mounted) return;
          chapterPageCounts[chapterIndex] = pages;
          _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
          totalPagesInBook = _cachedKnownPagesTotal;

          // Update chapter page numbers and UI every 10 chapters to reduce overhead
          if (chapterIndex % 10 == 0 || chapterIndex == _chapters.length - 1) {
            _updateChapterPageNumbers();
            if (mounted) setState(() {});
          }
        },
        shouldStop: () => !mounted,
      );

      if (!mounted) return;

      // Update all calculated values
      for (var entry in results.entries) {
        chapterPageCounts[entry.key] = entry.value;
      }

      _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
      totalPagesInBook = _cachedKnownPagesTotal;
      allChaptersCalculated.value = chapterPageCounts.length == _chapters.length;

      if (allChaptersCalculated.value) {
        controllerPaging.totalPages.value = totalPagesInBook;
        _saveCachedPageCounts();
      }

      _updateChapterPageNumbers();

      _isBackgroundCalcRunning = false;
      isCalculatingTotalPages = false;
      if (mounted) setState(() {});
    });
  }

  Future<void> _precalculateAllChaptersBlocking() async {
    if (_isBackgroundCalcRunning) return;

    // Wait for first frame to get correct MediaQuery size
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_isBackgroundCalcRunning) return;

    _isBackgroundCalcRunning = true;
    isCalculatingTotalPages = true;
    if (mounted) setState(() {});

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final pageSize = Size(screenWidth, screenHeight);

    // Calculate priority: Current -> End, then Previous -> 0
    final currentIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    List<int> priorityList = [];
    for (int i = currentIdx; i < _chapters.length; i++) priorityList.add(i);
    for (int i = currentIdx - 1; i >= 0; i--) priorityList.add(i);

    final results = await _paginationHelper.precalculateAllChapters(
      priorityList: priorityList,
      existingPageCounts: chapterPageCounts,
      pageSize: pageSize,
      onChapterCalculated: (chapterIndex, pages) {
        if (!mounted) return;
        chapterPageCounts[chapterIndex] = pages;
        _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
        totalPagesInBook = _cachedKnownPagesTotal;

        // Update UI every 10 chapters to reduce overhead
        if (chapterIndex % 10 == 0 || chapterIndex == _chapters.length - 1) {
          _updateChapterPageNumbers();
          if (mounted) setState(() {});
        }
      },
      shouldStop: () => !mounted,
    );

    if (!mounted) return;

    for (var entry in results.entries) {
      chapterPageCounts[entry.key] = entry.value;
    }

    _cachedKnownPagesTotal = chapterPageCounts.values.fold(0, (sum, c) => sum + c);
    totalPagesInBook = _cachedKnownPagesTotal;
    allChaptersCalculated.value = chapterPageCounts.length == _chapters.length;

    if (allChaptersCalculated.value) {
      controllerPaging.totalPages.value = totalPagesInBook;
      _saveCachedPageCounts();
    }

    _updateChapterPageNumbers();

    _isBackgroundCalcRunning = false;
    isCalculatingTotalPages = false;
    if (mounted) setState(() {});
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
    // Only update if chaptersList is not empty (avoid unnecessary work)
    if (chaptersList.isEmpty) return;

    _paginationHelper.updateChapterPageNumbers(
      chaptersList,
      chapterPageCounts,
      _filteredToOriginalIndex,
    );
    // Don't call setState here - let the caller decide if UI update is needed
    // This avoids excessive rebuilds
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
    if (snapshot.connectionState == ConnectionState.none || snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingWidget();
    }
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

    // Collect ALL chapter and subchapter titles to match against in the text
    // This helps identify headings that should be bold in the rendered content
    List<String> subchapterTitles = [];

    // Find the list index of the current chapter (not the original epub index)
    int currentListIndex = -1;
    for (int i = 0; i < chaptersList.length; i++) {
      if (!chaptersList[i].isSubChapter) {
        final originalIdx = _filteredToOriginalIndex[i];
        if (originalIdx == currentChapterIndex) {
          currentListIndex = i;
          break;
        }
      }
    }

    // Collect subchapter titles that belong to the current chapter
    for (var chapter in chaptersList) {
      if (chapter.isSubChapter && chapter.parentChapterIndex == currentListIndex) {
        subchapterTitles.add(chapter.chapter);
      }
    }

    // Also add ALL chapter titles (both main chapters and subchapters) for matching
    // This ensures any chapter/subchapter title appearing in text will be detected
    for (var chapter in chaptersList) {
      if (!subchapterTitles.contains(chapter.chapter)) {
        subchapterTitles.add(chapter.chapter);
      }
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
      onPaginationComplete: _handleSubchapterPageMapping,
      chapterTitle: _getParentChapterTitleForParsing(currentChapterIndex),
      totalChapters: chaptersList.length,
      bookId: bookId,
      showNavBar: showHeader,
      subchapterTitles: subchapterTitles,
    );
  }

  /// Handle subchapter page mapping from pagination
  void _handleSubchapterPageMapping(Map<String, int> subchapterPageMap) {
    if (subchapterPageMap.isEmpty) return;

    // Only update global subchapter mapping when viewing the main chapter,
    // not when inside a subchapter (which changes the chapter title and offsets).
    if (_currentSubchapterTitle != null && _currentSubchapterTitle!.isNotEmpty) {
      print('⏭️ Skipping subchapter map update (inside subchapter: "$_currentSubchapterTitle")');
      return;
    }

    print('📥 Received subchapter page mapping: $subchapterPageMap');

    // Get current chapter's start page in book
    var currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    var originalChapterIdx = _filteredToOriginalIndex[currentChapterIdx] ?? currentChapterIdx;

    // CRITICAL: Store the subchapter page map for this chapter
    _subchapterPageMapByChapter[originalChapterIdx] = Map<String, int>.from(subchapterPageMap);
    print('💾 Stored subchapter map for chapter $originalChapterIdx: $subchapterPageMap');

    int parentStartPageInBook = 0;
    for (int j = 0; j < originalChapterIdx; j++) {
      if (chapterPageCounts.containsKey(j)) {
        parentStartPageInBook += chapterPageCounts[j]!;
      }
    }
    parentStartPageInBook += 1; // 1-indexed

    // Update subchapter page numbers in chaptersList
    for (int i = 0; i < chaptersList.length; i++) {
      if (!chaptersList[i].isSubChapter) continue;
      if (chaptersList[i].parentChapterIndex != currentChapterIdx) continue;

      final subchapterTitle = chaptersList[i].chapter;
      int? pageInChapter = subchapterPageMap[subchapterTitle];

      if (pageInChapter != null) {
        // pageInChapter is 0-indexed from pagination
        // parentStartPageInBook is already 1-indexed
        int pageInBook = parentStartPageInBook + pageInChapter;

        chaptersList[i] = LocalChapterModel(
          chapter: chaptersList[i].chapter,
          isSubChapter: true,
          startPage: pageInBook,
          endPage: pageInBook,
          pageCount: 1,
          parentChapterIndex: chaptersList[i].parentChapterIndex,
          pageInChapter: pageInChapter, // Keep 0-indexed for comparison
        );

        print('✅ Updated subchapter "${subchapterTitle}" -> startPage: $pageInBook (parent: $parentStartPageInBook, offset: $pageInChapter)');
      }
    }

    // Trigger UI update
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle paging controller callback
  void _handlePagingCallback(PagingTextHandler ctrl) {
    controllerPaging = ctrl;
    int calculatedTotal = chapterPageCounts.values.fold(0, (s, c) => s + c);
    int bookTotal = _pendingTotalPages ?? (allChaptersCalculated.value ? totalPagesInBook : (calculatedTotal > 0 ? calculatedTotal : totalPagesInBook));
    final currentTotal = controllerPaging.totalPages.value;

    // During recalculation, use preserved totalPagesInBook instead of partial calculation
    // If we have a pending total (from jump), use it; otherwise use calculated
    final preservedTotal = _preservedTotalPages > 0 ? _preservedTotalPages : null;
    final displayTotal = _isJumpLockActive
        ? (_jumpLockedTotalPages ??
            _pendingTotalPages ??
            (isCalculatingTotalPages ? (preservedTotal ?? bookTotal) : (allChaptersCalculated.value ? bookTotal : (totalPagesInBook > 0 ? totalPagesInBook : bookTotal))))
        : (_pendingTotalPages ?? (isCalculatingTotalPages ? (preservedTotal ?? bookTotal) : (allChaptersCalculated.value ? bookTotal : (totalPagesInBook > 0 ? totalPagesInBook : bookTotal))));
    final shouldUpdate = _isJumpLockActive || _pendingTotalPages != null || allChaptersCalculated.value || currentTotal == 0 || (displayTotal > currentTotal && (displayTotal - currentTotal) > 5);

    if (shouldUpdate) {
      controllerPaging.totalPages.value = displayTotal;
    }

    // CRITICAL: Don't overwrite currentPage during pagination unless we have a pending jump
    if (_pendingCurrentPageInBook != null || _jumpLockedPageInBook != null) {
      print('🔄 _handlePagingCallback: Setting page to ${_jumpLockedPageInBook ?? _pendingCurrentPageInBook} (pending: $_pendingCurrentPageInBook, locked: $_jumpLockedPageInBook)');
      controllerPaging.currentPage.value = _jumpLockedPageInBook ?? _pendingCurrentPageInBook!;
      if (!_isJumpLockActive) _pendingCurrentPageInBook = null;
    } else {
      print('⏸️ _handlePagingCallback: Keeping current page ${controllerPaging.currentPage.value} (no pending)');
    }
    // Only clear pending total after it's been applied and not locked
    if (_pendingTotalPages != null && !_isJumpLockActive) _pendingTotalPages = null;
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
    return Obx(() {
      final currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
      final currentChapterTitle = currentChapterIdx >= 0 && currentChapterIdx < chaptersList.length ? chaptersList[currentChapterIdx].chapter : '';
      final originalChapterIdx = _filteredToOriginalIndex[currentChapterIdx] ?? currentChapterIdx;
      final isCurrentChapterCalculated = chapterPageCounts.containsKey(originalChapterIdx);
      final isCalculatingUi = isCalculatingTotalPages;

      return EpubBottomNavWidget(
        showHeader: showHeader,
        fontColor: fontColor,
        backColor: backColor,
        currentPage: controllerPaging.currentPage.value,
        totalPages: controllerPaging.totalPages.value,
        isCalculating: !isCurrentChapterCalculated || isCalculatingUi,
        chapterTitle: currentChapterTitle,
        onMenuPressed: openTableOfContents,
        onNextPage: () => controllerPaging.goToNextPage(),
        onPreviousPage: () => controllerPaging.goToPreviousPage(),
        onJumpToPage: (targetPageInBook) {
          final result = _calculateChapterAndPageFromBookPage(targetPageInBook);
          if (result != null) {
            // Preserve the target page and total pages so they're displayed after chapter loads
            final filteredIndex = _originalToFilteredIndex(result['chapter']!);
            _setJumpLock(
              pageInBook: targetPageInBook,
              totalPages: controllerPaging.totalPages.value,
              chapterIndex: filteredIndex,
              pageInChapter: result['page']!,
            );
            reLoadChapter(index: filteredIndex, startPage: result['page']!);
          } else {}
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
      );
    });
  }
}
