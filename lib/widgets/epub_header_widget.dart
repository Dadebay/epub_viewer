import 'package:cosmos_epub/book_options_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Header widget for EPUB reader with back button and options menu
class EpubHeaderWidget extends StatelessWidget {
  final bool showHeader;
  final Color fontColor;
  final Color backColor;
  final String bookTitle;
  final String? bookImage;
  final String bookId;
  final int staticThemeId;
  final Color buttonBackgroundColor;
  final Color buttonIconColor;
  final VoidCallback onBackPressed;

  const EpubHeaderWidget({
    Key? key,
    required this.showHeader,
    required this.fontColor,
    required this.backColor,
    required this.bookTitle,
    required this.bookImage,
    required this.bookId,
    required this.onBackPressed,
    required this.staticThemeId,
    required this.buttonBackgroundColor,
    required this.buttonIconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !showHeader,
        child: AnimatedOpacity(
          opacity: showHeader ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            height: showHeader ? 60.h : 0,
            duration: const Duration(milliseconds: 200),
            child: ClipRect(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.h,
                      decoration: BoxDecoration(
                        color: buttonBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: onBackPressed,
                        icon: Icon(
                          Icons.close,
                          color: buttonIconColor,
                          size: 16.sp,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    BookOptionsMenu(
                      fontColor: buttonIconColor,
                      backColor: backColor,
                      bookTitle: bookTitle,
                      bookImage: bookImage ?? '',
                      bookId: bookId,
                      staticThemeId: staticThemeId,
                      buttonBackgroundColor: buttonBackgroundColor,
                      buttonIconColor: buttonIconColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
