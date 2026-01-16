import 'package:cosmos_epub/models/book_progress_model.dart';
import 'package:cosmos_epub/models/chapter_model.dart';
import 'package:isar_community/isar.dart';

class BookPageTracker {
  final Isar isar;

  BookPageTracker(this.isar);

  // Update page count for a specific chapter
  Future<void> updateChapterPageCount(
    String bookId,
    int chapterIndex,
    int pageCount,
  ) async {
    var progress = await isar.bookProgressModels.filter().bookIdEqualTo(bookId).findFirst();

    if (progress == null) {
      progress = BookProgressModel(
        bookId: bookId,
        chapterPageCounts: [],
        currentChapterIndex: 0,
        currentPageIndex: 0,
      );
    }

    // Initialize list if needed
    progress.chapterPageCounts ??= [];

    // Expand list to accommodate chapter index
    while (progress.chapterPageCounts!.length <= chapterIndex) {
      progress.chapterPageCounts!.add(0);
    }

    // Only update if changed (avoid unnecessary writes)
    if (progress.chapterPageCounts![chapterIndex] != pageCount) {
      progress.chapterPageCounts![chapterIndex] = pageCount;

      await isar.writeTxn(() async {
        await isar.bookProgressModels.put(progress!);
      });
    }
  }

  // Get total pages for the book
  Future<int> getTotalPages(String bookId) async {
    var progress = await isar.bookProgressModels.filter().bookIdEqualTo(bookId).findFirst();

    if (progress?.chapterPageCounts == null) return 0;

    return progress!.chapterPageCounts!.fold<int>(0, (int sum, int count) => sum + count);
  }

  // Get page counts as a list
  Future<List<int>> getChapterPageCounts(String bookId) async {
    var progress = await isar.bookProgressModels.filter().bookIdEqualTo(bookId).findFirst();

    return progress?.chapterPageCounts ?? [];
  }

  // Get current global page number
  Future<int> getCurrentGlobalPage(String bookId) async {
    var progress = await isar.bookProgressModels.filter().bookIdEqualTo(bookId).findFirst();

    if (progress == null) return 1;

    int globalPage = 1;
    int currentChapter = progress.currentChapterIndex ?? 0;
    int currentPage = progress.currentPageIndex ?? 0;

    // Add pages from previous chapters
    if (progress.chapterPageCounts != null) {
      for (int i = 0; i < currentChapter && i < progress.chapterPageCounts!.length; i++) {
        globalPage += progress.chapterPageCounts![i];
      }
    }

    // Add current page in current chapter
    globalPage += currentPage;

    return globalPage;
  }

  // Update chapter models with page info
  Future<void> updateChapterModelsWithPages(
    String bookId,
    List<LocalChapterModel> chapters,
  ) async {
    var pageCounts = await getChapterPageCounts(bookId);

    int cumulativePage = 1;
    for (int i = 0; i < chapters.length; i++) {
      int pageCount = i < pageCounts.length ? pageCounts[i] : 0;

      chapters[i].pageCount = pageCount;
      chapters[i].startPage = cumulativePage;
      chapters[i].endPage = pageCount > 0 ? cumulativePage + pageCount - 1 : 0;

      if (pageCount > 0) {
        cumulativePage = chapters[i].endPage + 1;
      }
    }
  }
}
