import 'package:cached_network_image/cached_network_image.dart';
import 'package:cosmos_epub/helpers/functions.dart';
import 'package:cosmos_epub/models/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ChaptersBottomSheet extends StatefulWidget {
  const ChaptersBottomSheet({
    super.key,
    required this.title,
    required this.chapters,
    required this.bookId,
    required this.imageUrl,
    required this.accentColor,
    required this.chapterListTitle,
    required this.currentPage,
    required this.totalPages,
    required this.chapterPageCounts,
    required this.subchapterPageMapByChapter,
    required this.filteredToOriginalIndex,
    this.currentPageInChapter = 0,
    this.currentSubchapterTitle,
    this.isCalculating = false,
  });

  final Color accentColor;
  final String bookId;
  final String chapterListTitle;
  final Map<int, int> chapterPageCounts;
  final List<LocalChapterModel> chapters;
  final int currentPage;
  final int currentPageInChapter;
  final String? currentSubchapterTitle;
  final Map<int, int> filteredToOriginalIndex;
  final String imageUrl;
  final bool isCalculating;
  final Map<int, Map<String, int>> subchapterPageMapByChapter;
  final String title;
  final int totalPages;

  @override
  State<ChaptersBottomSheet> createState() => _ChaptersBottomSheetState();
}

class _ChaptersBottomSheetState extends State<ChaptersBottomSheet> {
  int _calculateSubchapterStartPage(LocalChapterModel chapter) {
    if (!chapter.isSubChapter) {
      return chapter.startPage;
    }

    final parentChapterIndex = chapter.parentChapterIndex;
    final originalParentIndex = widget.filteredToOriginalIndex[parentChapterIndex] ?? parentChapterIndex;

    int parentStartPageInBook = 1;
    for (int j = 0; j < originalParentIndex; j++) {
      if (widget.chapterPageCounts.containsKey(j)) {
        parentStartPageInBook += widget.chapterPageCounts[j]!;
      }
    }

    final mapForChapter = widget.subchapterPageMapByChapter[originalParentIndex];
    final offsetInChapter = mapForChapter != null && mapForChapter.containsKey(chapter.chapter) ? mapForChapter[chapter.chapter]! : chapter.pageInChapter;

    int startPage = parentStartPageInBook + offsetInChapter;

    return startPage;
  }

  int _calculateSubchapterPageInChapter(LocalChapterModel chapter) {
    if (!chapter.isSubChapter) return 0;
    final parentChapterIndex = chapter.parentChapterIndex;
    final originalParentIndex = widget.filteredToOriginalIndex[parentChapterIndex] ?? parentChapterIndex;
    final mapForChapter = widget.subchapterPageMapByChapter[originalParentIndex];
    if (mapForChapter != null && mapForChapter.containsKey(chapter.chapter)) {
      return mapForChapter[chapter.chapter]!;
    }
    return chapter.pageInChapter;
  }

  @override
  Widget build(BuildContext context) {
    String allChapterText = widget.chapters.map((c) => c.chapter).join(' ');
    TextDirection textDirection = RTLHelper.getTextDirection(allChapterText);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Directionality(
          textDirection: textDirection,
          child: Container(
            decoration: BoxDecoration(
              color: Get.isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 80,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const LoadingWidget(
                            height: 80,
                            animationWidth: 40,
                            animationHeight: 40,
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(Icons.broken_image, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              textDirection: textDirection,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Get.isDarkMode ? Colors.white : Colors.black,
                                fontSize: 16.sp,
                              ),
                            ),
                            if (widget.totalPages > 0 || widget.isCalculating) ...[
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    '${CosmosEpubLocalization.t('page')} ',
                                    style: TextStyle(
                                      color: Get.isDarkMode ? Colors.white54 : Colors.black.withOpacity(0.6),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (widget.isCalculating)
                                    SizedBox(
                                      width: 12.w,
                                      height: 12.h,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Get.isDarkMode ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '${widget.currentPageInChapter} ${CosmosEpubLocalization.t('of')} ${widget.totalPages}',
                                      style: TextStyle(
                                        color: Get.isDarkMode ? Colors.white54 : Colors.black.withOpacity(0.6),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(null),
                        child: CircleAvatar(
                          backgroundColor: Get.isDarkMode ? Colors.black54 : Colors.grey[300],
                          child: Icon(
                            Icons.close,
                            color: fontColor,
                            size: 20.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.2)),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: widget.chapters.length,
                    separatorBuilder: (context, index) {
                      bool currentIsSubchapter = widget.chapters[index].isSubChapter;
                      bool nextIsSubchapter = index + 1 < widget.chapters.length && widget.chapters[index + 1].isSubChapter;

                      if (currentIsSubchapter && nextIsSubchapter) {
                        return Divider(
                          height: 1,
                          thickness: 0.3,
                          color: Colors.grey.withOpacity(0.2),
                          indent: 52.w,
                          endIndent: 16.w,
                        );
                      }

                      return Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.grey.withOpacity(0.3),
                        indent: 16.w,
                        endIndent: 16.w,
                      );
                    },
                    itemBuilder: (context, i) {
                      final chapter = widget.chapters[i];
                      final currentChapterIndex = bookProgress.getBookProgress(widget.bookId).currentChapterIndex ?? 0;

                      bool isCurrentChapter = false;

                      if (widget.currentSubchapterTitle != null && widget.currentSubchapterTitle!.isNotEmpty) {
                        if (chapter.isSubChapter && chapter.chapter == widget.currentSubchapterTitle) {
                          isCurrentChapter = true;
                        }
                      } else {
                        if (!chapter.isSubChapter && currentChapterIndex == i) {
                          isCurrentChapter = true;
                        }
                      }

                      return InkWell(
                        onTap: () async {
                          if (chapter.isSubChapter && chapter.parentChapterIndex >= 0) {
                            final dynamicPageInChapter = _calculateSubchapterPageInChapter(chapter);
                            final dynamicStartPage = _calculateSubchapterStartPage(chapter);

                            Navigator.of(context).pop({
                              'isSubChapter': true,
                              'chapterIndex': chapter.parentChapterIndex,
                              'pageIndex': dynamicPageInChapter,
                              'subchapterIndex': i,
                              'subchapterTitle': chapter.chapter,
                              'startPage': dynamicStartPage,
                            });
                            return;
                          }

                          if (i == bookProgress.getBookProgress(widget.bookId).currentChapterIndex) {
                            Navigator.of(context).pop({
                              'isSubChapter': false,
                              'chapterIndex': i,
                              'pageIndex': 0,
                            });
                            return;
                          }

                          Navigator.of(context).pop({'isSubChapter': false, 'chapterIndex': i, 'pageIndex': 0});
                        },
                        child: Container(
                          color: isCurrentChapter
                              ? Get.isDarkMode
                                  ? Colors.black
                                  : Colors.grey[400]
                              : Get.isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (widget.chapters[i].isSubChapter) ...[
                                      SizedBox(width: textDirection == TextDirection.ltr ? 24.w : 0),
                                      Icon(
                                        Icons.circle,
                                        size: 6.h,
                                        color: isCurrentChapter
                                            ? Get.isDarkMode
                                                ? Colors.white70
                                                : Colors.black54
                                            : Get.isDarkMode
                                                ? Colors.white38
                                                : Colors.black38,
                                      ),
                                      SizedBox(width: 12.w),
                                    ],
                                    Expanded(
                                      child: Text(
                                        widget.chapters[i].chapter,
                                        textDirection: RTLHelper.getTextDirection(widget.chapters[i].chapter),
                                        style: TextStyle(
                                          color: isCurrentChapter
                                              ? Get.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black
                                              : Get.isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87,
                                          fontSize: widget.chapters[i].isSubChapter ? 14.sp : 15.sp,
                                          fontWeight: widget.chapters[i].isSubChapter ? FontWeight.w400 : FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (widget.chapters[i].isSubChapter) ...[
                                      SizedBox(width: textDirection == TextDirection.rtl ? 24.w : 0),
                                    ],
                                  ],
                                ),
                              ),
                              if (_calculateSubchapterStartPage(widget.chapters[i]) > 0)
                                Text(
                                  '${_calculateSubchapterStartPage(widget.chapters[i])}',
                                  style: TextStyle(
                                    color: isCurrentChapter
                                        ? Get.isDarkMode
                                            ? Colors.white70
                                            : Colors.black
                                        : Get.isDarkMode
                                            ? Colors.white38
                                            : Colors.black54,
                                    fontWeight: isCurrentChapter ? FontWeight.w600 : FontWeight.w400,
                                    fontSize: 13.sp,
                                  ),
                                )
                              else if (widget.isCalculating)
                                SizedBox(
                                  width: 14.w,
                                  height: 14.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Get.isDarkMode ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
