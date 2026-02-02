import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ProgressBarWidget extends StatefulWidget {
  const ProgressBarWidget({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    this.isCalculating = false,
    this.onNextPage,
    this.onPreviousPage,
    this.onJumpToPage,
    this.chapterTitle,
    this.backgroundColor,
    this.textColor,
    this.onLongPressStateChanged,
    required this.staticThemeId,
    required this.buttonBackgroundColor,
    required this.buttonIconColor,
  }) : super(key: key);

  final Function(int targetPage)? onJumpToPage;
  final Function(bool isLongPressing)? onLongPressStateChanged;
  final Color? backgroundColor;
  final Color buttonBackgroundColor;
  final Color buttonIconColor;
  final String? chapterTitle;
  final int currentPage;
  final bool isCalculating;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final int staticThemeId;
  final Color? textColor;
  final int totalPages;

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget> {
  double _dragStartX = 0;
  bool _hasDraggedSignificantly = false;
  bool _isDragging = false;
  int _lastHapticPage = -1;
  OverlayEntry? _overlayEntry;
  double _progressBarWidth = 0;
  int _targetPage = 0;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlayContent(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlayContent() {
    final displayPage = _isDragging ? _targetPage : widget.currentPage;

    return Positioned(
      bottom: 120.h,
      left: 70.w,
      right: 70.w,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: Get.size.width,
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: widget.buttonBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page'.tr + ' ' + '$displayPage / ${widget.totalPages}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: widget.buttonIconColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.isCalculating) ...[
                      SizedBox(width: 6.w),
                      SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.buttonIconColor.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.chapterTitle != null && widget.chapterTitle!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    widget.chapterTitle!,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: widget.buttonIconColor.withOpacity(0.6),
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  int _calculatePageFromPosition(double localX) {
    if (_progressBarWidth <= 0) {
      return widget.currentPage;
    }

    final progress = (localX / _progressBarWidth).clamp(0.0, 1.0);
    final targetPage = (progress * widget.totalPages).round();
    final clampedPage = targetPage.clamp(1, widget.totalPages);

    return clampedPage;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onHorizontalDragStart: (details) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          _dragStartX = localPosition.dx;
          _hasDraggedSignificantly = false;

          HapticFeedback.mediumImpact();
          setState(() {
            _isDragging = true;
            _targetPage = widget.currentPage;
            _lastHapticPage = widget.currentPage;
          });
          widget.onLongPressStateChanged?.call(true);
          _showOverlay();
        },
        onHorizontalDragUpdate: (details) {
          if (_isDragging) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localPosition = box.globalToLocal(details.globalPosition);
            final progressBarPadding = 16.w;
            final localX = localPosition.dx - progressBarPadding;

            if (!_hasDraggedSignificantly && (localPosition.dx - _dragStartX).abs() > 10) {
              _hasDraggedSignificantly = true;
            }

            setState(() {
              _progressBarWidth = box.size.width - (progressBarPadding * 2);
              _targetPage = _calculatePageFromPosition(localX);
            });

            if (_targetPage != _lastHapticPage) {
              HapticFeedback.selectionClick();
              _lastHapticPage = _targetPage;
            }

            _updateOverlay();
          }
        },
        onHorizontalDragEnd: (details) {
          _removeOverlay();

          if (_hasDraggedSignificantly && _targetPage != widget.currentPage && widget.onJumpToPage != null) {
            HapticFeedback.mediumImpact();
            widget.onJumpToPage!(_targetPage);
          } else if (!_hasDraggedSignificantly && _targetPage != widget.currentPage && widget.onJumpToPage != null) {
            HapticFeedback.mediumImpact();
            widget.onJumpToPage!(_targetPage);
          } else {
            HapticFeedback.lightImpact();
          }

          setState(() {
            _isDragging = false;
            _targetPage = widget.currentPage;
            _lastHapticPage = -1;
            _hasDraggedSignificantly = false;
          });
          widget.onLongPressStateChanged?.call(false);
        },
        onTapDown: (details) {
          HapticFeedback.mediumImpact();
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final progressBarPadding = 16.w;
          final localX = localPosition.dx - progressBarPadding;

          _progressBarWidth = box.size.width - (progressBarPadding * 2);
          final targetPage = _calculatePageFromPosition(localX);

          if (targetPage != widget.currentPage && widget.onJumpToPage != null) {
            widget.onJumpToPage!(targetPage);
          } else {}
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isDragging ? 1.03 : 1.0),
          child: Container(
            height: 40.h,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            width: Get.size.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: widget.buttonBackgroundColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = widget.totalPages > 0 ? (_isDragging ? (_targetPage / widget.totalPages).clamp(0.0, 1.0) : (widget.currentPage / widget.totalPages).clamp(0.0, 1.0)) : 0.0;

                      return AnimatedContainer(
                        duration: Duration(milliseconds: _isDragging ? 50 : 300),
                        curve: Curves.easeOut,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: widget.isCalculating ? Colors.transparent : Color(0xFF8E8E93).withOpacity(.5),
                        ),
                      );
                    },
                  ),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: widget.isCalculating ? '' : '${_isDragging ? _targetPage : widget.currentPage}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: widget.buttonIconColor.withOpacity(0.6),
                              letterSpacing: -0.5,
                              height: 0.5,
                            ),
                          ),
                          TextSpan(
                            text: widget.isCalculating ? '' : ' /',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 16.sp,
                              color: widget.buttonIconColor.withOpacity(0.6),
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: widget.isCalculating ? '' : ' ${widget.totalPages}',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: widget.buttonIconColor.withOpacity(0.6),
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (widget.isCalculating)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                margin: EdgeInsets.only(left: 8.w),
                                width: 14.w,
                                height: 14.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.buttonIconColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
