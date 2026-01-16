import 'package:isar_community/isar.dart';

part 'book_progress_model.g.dart';

@collection
@Name("BookProgressModel")
class BookProgressModel {
  Id localId = Isar.autoIncrement;
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
