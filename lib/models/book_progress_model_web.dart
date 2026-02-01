// Web için basitleştirilmiş model - Isar kullanmaz
class BookProgressModel {
  String? bookId;
  int? currentChapterIndex;
  int? currentPageIndex;
  List<int>? chapterPageCounts;

  BookProgressModel({
    this.currentChapterIndex,
    this.currentPageIndex,
    this.bookId,
    this.chapterPageCounts,
  });
}
