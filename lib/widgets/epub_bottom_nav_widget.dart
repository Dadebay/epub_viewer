import 'package:cosmos_epub/helpers/progress_bar_widget.dart';
import 'package:cosmos_epub/widgets/font_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom navigation bar widget for EPUB reader
class EpubBottomNavWidget extends StatefulWidget {
  final bool showHeader;
  final Color fontColor;
  final Color backColor;
  final int currentPage;
  final int totalPages;
  final bool isCalculating;
  final String chapterTitle;
  final VoidCallback onMenuPressed;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final Function(int) onJumpToPage;
  final VoidCallback onFontSettingsPressed;
  final double fontSize;
  final double brightnessLevel;
  final int staticThemeId;
  final Color buttonBackgroundColor;
  final Color buttonIconColor;
  final Function(double) setBrightness;
  final Function(int id, {bool? forceDarkMode}) updateTheme;
  final Function(double) onFontSizeChange;
  final Function(bool)? onProgressLongPressChanged;

  const EpubBottomNavWidget({
    Key? key,
    required this.showHeader,
    required this.fontColor,
    required this.backColor,
    required this.currentPage,
    required this.totalPages,
    required this.isCalculating,
    required this.chapterTitle,
    required this.onMenuPressed,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onJumpToPage,
    required this.onFontSettingsPressed,
    required this.fontSize,
    required this.brightnessLevel,
    required this.staticThemeId,
    required this.buttonBackgroundColor,
    required this.buttonIconColor,
    required this.setBrightness,
    required this.updateTheme,
    required this.onFontSizeChange,
    this.onProgressLongPressChanged,
  }) : super(key: key);

  @override
  State<EpubBottomNavWidget> createState() => _EpubBottomNavWidgetState();
}

class _EpubBottomNavWidgetState extends State<EpubBottomNavWidget> {
  bool _isProgressLongPressed = false;

  Widget _buildNavButton({
    required String image,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        color: widget.buttonBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22.r),
          splashColor: widget.fontColor.withOpacity(0.1),
          highlightColor: widget.fontColor.withOpacity(0.05),
          child: Center(
            child: Image.asset(
              image,
              package: 'cosmos_epub',
              fit: BoxFit.contain,
              color: widget.buttonIconColor,
              width: image == 'assets/images/font_logo.png' ? 24.sp : 15.sp,
              height: image == 'assets/images/font_logo.png' ? 24.sp : 15.sp,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('📖 EPUB Page Info - Current Page: ${widget.currentPage}, Total Pages: ${widget.totalPages}');

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !widget.showHeader,
        child: AnimatedContainer(
          height: widget.showHeader ? 70.h : 30.h,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: ClipRect(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: widget.showHeader ? 8.h : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.showHeader) ...[
                      AnimatedOpacity(
                        opacity: _isProgressLongPressed ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: _buildNavButton(
                          image: 'assets/images/content_list.png',
                          onPressed: widget.onMenuPressed,
                          tooltip: 'Table of Contents',
                        ),
                      ),
                    ],
                    Expanded(
                      child: widget.showHeader
                          ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              child: ProgressBarWidget(
                                currentPage: widget.currentPage,
                                totalPages: widget.totalPages,
                                isCalculating: widget.isCalculating,
                                onNextPage: widget.onNextPage,
                                onPreviousPage: widget.onPreviousPage,
                                onJumpToPage: widget.onJumpToPage,
                                chapterTitle: widget.chapterTitle,
                                backgroundColor: widget.backColor,
                                textColor: widget.fontColor,
                                onLongPressStateChanged: (isLongPressing) {
                                  setState(() {
                                    _isProgressLongPressed = isLongPressing;
                                  });
                                  widget.onProgressLongPressChanged?.call(isLongPressing);
                                },
                                staticThemeId: widget.staticThemeId,
                                buttonBackgroundColor: widget.buttonBackgroundColor,
                                buttonIconColor: widget.buttonIconColor,
                              ),
                            )
                          : Center(
                              child: Text(
                                "${widget.currentPage}",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                    if (widget.showHeader) ...[
                      AnimatedOpacity(
                        opacity: _isProgressLongPressed ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: _buildNavButton(
                          image: 'assets/images/font_logo.png',
                          onPressed: () {
                            updateFontSettings(
                              context: context,
                              backColor: widget.backColor,
                              fontColor: widget.fontColor,
                              brightnessLevel: widget.brightnessLevel,
                              staticThemeId: widget.staticThemeId,
                              setBrightness: widget.setBrightness,
                              updateTheme: widget.updateTheme,
                              fontSizeProgress: widget.fontSize,
                              onFontSizeChange: widget.onFontSizeChange,
                            );
                          },
                          tooltip: 'Font Settings',
                        ),
                      ),
                    ],
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
