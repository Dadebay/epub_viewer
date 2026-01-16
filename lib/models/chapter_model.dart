// class LocalChapterModel {
//   final String chapter;
//   bool isSubChapter = false;

//   LocalChapterModel({required this.chapter, required this.isSubChapter});
// }

class LocalChapterModel {
  final String chapter;
  bool isSubChapter = false;
  int startPage = 0;
  int endPage = 0;
  int pageCount = 0;
  int parentChapterIndex = -1; // For sub-chapters: which main chapter they belong to
  int pageInChapter = 0; // For sub-chapters: which page within the parent chapter

  LocalChapterModel({
    required this.chapter,
    required this.isSubChapter,
    this.startPage = 0,
    this.endPage = 0,
    this.pageCount = 0,
    this.parentChapterIndex = -1,
    this.pageInChapter = 0,
  });
}
