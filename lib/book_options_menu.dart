import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookOptionsMenu extends StatefulWidget {
  final Color fontColor;
  final Color backColor;
  final String bookTitle;
  final String bookImage;
  final String bookId;
  final int staticThemeId;
  final Color buttonBackgroundColor;
  final Color buttonIconColor;

  const BookOptionsMenu({
    Key? key,
    required this.fontColor,
    required this.backColor,
    required this.bookTitle,
    required this.bookImage,
    required this.bookId,
    required this.staticThemeId,
    required this.buttonBackgroundColor,
    required this.buttonIconColor,
  }) : super(key: key);

  @override
  State<BookOptionsMenu> createState() => _BookOptionsMenuState();
}

class _BookOptionsMenuState extends State<BookOptionsMenu> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.h,
      decoration: BoxDecoration(
        color: widget.buttonBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_horiz,
          color: widget.buttonIconColor,
          size: 20.sp,
        ),
        color: widget.backColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        elevation: 8,
        padding: EdgeInsets.zero,
        offset: Offset(0, 45.h),
        onSelected: (value) {
          switch (value) {
            case 'book_description':
              openBookDescription(context);
              break;
            case 'add_to_shelf':
            case 'remove_from_shelf':
              toggleShelf();
              break;
            case 'save_to_my_books':
            case 'remove_from_my_books':
              toggleMyBooks();
              break;
          }
        },
        itemBuilder: (BuildContext context) => [
          _buildMenuItem(
            label: CosmosEpubLocalization.t('book_description'),
            value: 'book_description',
            icon: Icons.description_outlined,
            fontColor: widget.fontColor,
            showDivider: true,
          ),
          _buildMenuItem(
            label: CosmosEpub.isInShelf ? CosmosEpubLocalization.t('remove_from_shelf') : CosmosEpubLocalization.t('add_to_shelf'),
            value: CosmosEpub.isInShelf ? 'remove_from_shelf' : 'add_to_shelf',
            icon: CosmosEpub.isInShelf ? Icons.bookmark : Icons.bookmark_border,
            fontColor: widget.fontColor,
            showDivider: true,
          ),
          _buildMenuItem(
            label: CosmosEpub.isInMyBooks ? CosmosEpubLocalization.t('remove_from_my_books') : CosmosEpubLocalization.t('save_to_my_books'),
            value: CosmosEpub.isInMyBooks ? 'remove_from_my_books' : 'save_to_my_books',
            icon: CosmosEpub.isInMyBooks ? Icons.check_circle : Icons.add_circle_outline,
            fontColor: widget.fontColor,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _buildMenuItem({
    required String label,
    required String value,
    required IconData icon,
    required Color fontColor,
    bool showDivider = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w400,
                      color: fontColor,
                    ),
                  ),
                ),
                Icon(
                  icon,
                  size: 22.sp,
                  color: fontColor,
                ),
              ],
            ),
          ),
          if (showDivider)
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: fontColor.withOpacity(0.2),
              indent: 16.w,
              endIndent: 16.w,
            ),
        ],
      ),
    );
  }

  void openBookDescription(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.backColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: widget.backColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.network(
                          widget.bookImage,
                          width: 80.w,
                          height: 120.h,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80.w,
                              height: 120.h,
                              color: Colors.grey,
                              child: Icon(Icons.book, color: Colors.white),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bookTitle,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: widget.fontColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    CosmosEpubLocalization.t('book_description'),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.fontColor,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        CosmosEpub.bookDescription,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: widget.fontColor.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void toggleShelf() async {
    await CosmosEpub.onAddToShelf(widget.bookId);
    // Wait a bit for dialogs to close, then rebuild
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {});
    }
  }

  void toggleMyBooks() async {
    await CosmosEpub.onSaveToMyBooks(widget.bookId);
    // Wait a bit for dialogs to close, then rebuild
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {});
    }
  }
}
