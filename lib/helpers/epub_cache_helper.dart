import 'dart:developer';
import 'package:get_storage/get_storage.dart';

/// Helper class for managing EPUB page count caching
class EpubCacheHelper {
  final String bookId;
  final GetStorage gs;

  EpubCacheHelper({
    required this.bookId,
    required this.gs,
  });

  /// Load cached page counts from storage
  /// Returns empty map if cache is invalid (font size/theme/screen size changed)
  Map<int, int> loadCachedPageCounts(int totalChapters,
      {double? fontSize,
      int? themeId,
      double? screenWidth,
      double? screenHeight}) {
    final cached = gs.read('book_${bookId}_page_counts');
    final cachedFontSize = gs.read('book_${bookId}_cache_font_size');
    final cachedThemeId = gs.read('book_${bookId}_cache_theme_id');
    final cachedScreenWidth = gs.read('book_${bookId}_cache_screen_width');
    final cachedScreenHeight = gs.read('book_${bookId}_cache_screen_height');
    Map<int, int> chapterPageCounts = {};

    // Check if font size or theme changed - invalidate cache
    if (fontSize != null &&
        cachedFontSize != null &&
        (cachedFontSize - fontSize).abs() > 0.1) {
      log('📚 Cache invalidated: font size changed from $cachedFontSize to $fontSize');
      gs.remove('book_${bookId}_page_counts');
      return {};
    }
    if (themeId != null && cachedThemeId != null && cachedThemeId != themeId) {
      log('📚 Cache invalidated: theme changed from $cachedThemeId to $themeId');
      gs.remove('book_${bookId}_page_counts');
      return {};
    }
    // Check if screen size changed - invalidate cache (pagination depends on screen size)
    if (screenWidth != null &&
        cachedScreenWidth != null &&
        (cachedScreenWidth - screenWidth).abs() > 10) {
      log('📚 Cache invalidated: screen width changed from $cachedScreenWidth to $screenWidth');
      gs.remove('book_${bookId}_page_counts');
      return {};
    }
    if (screenHeight != null &&
        cachedScreenHeight != null &&
        (cachedScreenHeight - screenHeight).abs() > 10) {
      log('📚 Cache invalidated: screen height changed from $cachedScreenHeight to $screenHeight');
      gs.remove('book_${bookId}_page_counts');
      gs.remove('book_${bookId}_page_counts');
      return {};
    }

    // Check for daily expiration (24 hours)
    final cachedTimestamp = gs.read('book_${bookId}_cache_timestamp');
    if (cachedTimestamp != null) {
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();
      if (now.difference(cachedTime).inHours >= 24) {
        log('⏰ Cache expired (>24h), clearing... (Saved: $cachedTime)');
        clearCache();
        return {};
      }
    } else if (cached != null) {
      // If no timestamp but cache exists (legacy), treat as expired to be safe/migration
      // Or just keep it. Let's keep it but next save will add timestamp.
      log('⚠️ Cache exists without timestamp. Will be updated on next save.');
    }

    if (cached != null && cached is Map) {
      // Keys may have been stored as strings; normalize to int keys
      chapterPageCounts = cached.map<int, int>((key, value) {
        final intKey = key is int ? key : int.tryParse(key.toString()) ?? 0;
        return MapEntry(intKey, value as int);
      });

      // Validate cache: if cached chapters don't match current chapter count, clear cache
      if (chapterPageCounts.length != totalChapters) {
        chapterPageCounts.clear();
        gs.remove('book_${bookId}_page_counts');
        log('📚 Cache cleared, will recalculate all chapters');
        return {};
      }

      log('📚 Loaded ${chapterPageCounts.length} cached page counts');
    } else {
      log('📚 No cached page counts found, will calculate all chapters');
    }

    return chapterPageCounts;
  }

  /// Save page counts to storage along with font size, theme, and screen size
  void saveCachedPageCounts(Map<int, int> chapterPageCounts,
      {double? fontSize,
      int? themeId,
      double? screenWidth,
      double? screenHeight}) {
    // Store with string keys to keep JSON encoder happy
    final stringKeyed = chapterPageCounts.map<String, int>(
      (key, value) => MapEntry(key.toString(), value),
    );
    gs.write('book_${bookId}_page_counts', stringKeyed);
    if (fontSize != null) gs.write('book_${bookId}_cache_font_size', fontSize);
    if (themeId != null) gs.write('book_${bookId}_cache_theme_id', themeId);
    if (screenWidth != null)
      gs.write('book_${bookId}_cache_screen_width', screenWidth);
    if (screenHeight != null)
      gs.write('book_${bookId}_cache_screen_height', screenHeight);

    // Save current timestamp for daily expiration
    gs.write('book_${bookId}_cache_timestamp',
        DateTime.now().millisecondsSinceEpoch);

    log('💾 Saved page counts to cache (fontSize: $fontSize, themeId: $themeId, screen: ${screenWidth}x$screenHeight)');
  }

  /// Clear all cached page counts for this book
  void clearCache() {
    gs.remove('book_${bookId}_page_counts');
    gs.remove('book_${bookId}_cache_font_size');
    gs.remove('book_${bookId}_cache_theme_id');
    gs.remove('book_${bookId}_cache_screen_width');
    gs.remove('book_${bookId}_cache_screen_width');
    gs.remove('book_${bookId}_cache_screen_height');
    gs.remove('book_${bookId}_cache_timestamp');
    log('🗑️ Cleared cache for book $bookId');
  }
}
