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
  final String title;
  final List<LocalChapterModel> chapters;
  final String bookId;
  final String imageUrl;
  final Color accentColor;
  final String chapterListTitle;
  final int currentPage;
  final int totalPages;
  final int currentPageInChapter; // New parameter for current page within chapter
  final String? currentSubchapterTitle; // Currently active subchapter title
  final bool isCalculating; // Show loading while calculating total pages

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
    this.currentPageInChapter = 0, // Default to 0
    this.currentSubchapterTitle, // Current subchapter title
    this.isCalculating = false, // Default to false
  });

  @override
  State<ChaptersBottomSheet> createState() => _ChaptersBottomSheetState();
}

class _ChaptersBottomSheetState extends State<ChaptersBottomSheet> {
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
                // Header
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
                          color: Colors.red, // fallback background while loading
                          borderRadius: BorderRadius.circular(8), // optional
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl, // << put your URL here
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
                // Chapters list
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: widget.chapters.length,
                    separatorBuilder: (context, index) {
                      // Don't show separator between subchapters of same parent
                      bool currentIsSubchapter = widget.chapters[index].isSubChapter;
                      bool nextIsSubchapter = index + 1 < widget.chapters.length && widget.chapters[index + 1].isSubChapter;

                      if (currentIsSubchapter && nextIsSubchapter) {
                        // Both are subchapters - thin separator
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

                      // Check if this item is currently selected
                      bool isCurrentChapter = false;
                      if (chapter.isSubChapter && chapter.parentChapterIndex >= 0) {
                        // Sub-chapter: selected if parent chapter matches AND subchapter title matches
                        isCurrentChapter = (currentChapterIndex == chapter.parentChapterIndex && widget.currentSubchapterTitle != null && widget.currentSubchapterTitle == chapter.chapter);
                      } else {
                        // Regular chapter: selected if chapter index matches AND no subchapter is active
                        isCurrentChapter = (currentChapterIndex == i && widget.currentSubchapterTitle == null);
                      }

                      return InkWell(
                        onTap: () async {
                          // Handle sub-chapter navigation - return Map with navigation info
                          if (chapter.isSubChapter && chapter.parentChapterIndex >= 0) {
                            Navigator.of(context).pop({
                              'isSubChapter': true,
                              'chapterIndex': chapter.parentChapterIndex,
                              'pageIndex': chapter.pageInChapter,
                              'subchapterIndex': i, // Include the subchapter's own index
                              'subchapterTitle': chapter.chapter, // Include the subchapter's title
                              'startPage': chapter.startPage, // Include absolute page for book-level navigation
                            });
                            return;
                          }

                          // If tapping the current chapter, navigate to first page of chapter
                          if (i == bookProgress.getBookProgress(widget.bookId).currentChapterIndex) {
                            Navigator.of(context).pop({
                              'isSubChapter': false,
                              'chapterIndex': i,
                              'pageIndex': 0, // Go to first page of chapter
                            });
                            return;
                          }

                          Navigator.of(context).pop({
                            'isSubChapter': false,
                            'chapterIndex': i,
                            'pageIndex': 0,
                          });
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
                              // Chapter content
                              Expanded(
                                child: Row(
                                  children: [
                                    // Indent for subchapters
                                    if (widget.chapters[i].isSubChapter) ...[
                                      SizedBox(width: textDirection == TextDirection.ltr ? 24.w : 0),
                                      // Bullet point or icon for subchapter
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
                              // Show page number if available
                              if (widget.chapters[i].startPage > 0)
                                Text(
                                  '${widget.chapters[i].startPage}',
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
