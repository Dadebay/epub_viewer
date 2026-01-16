import 'dart:ui' as ui;

import 'package:cosmos_epub/page_flip/effects/flip_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

Map<int, ui.Image?> imageData = {};
ValueNotifier<int> currentPage = ValueNotifier(-1);
ValueNotifier<Widget> currentWidget = ValueNotifier(Container());
ValueNotifier<int> currentPageIndex = ValueNotifier(0);

class PageFlipBuilder extends StatefulWidget {
  const PageFlipBuilder({
    Key? key,
    required this.amount,
    this.backgroundColor,
    required this.child,
    required this.pageIndex,
    required this.isRightSwipe,
  }) : super(key: key);

  final Animation<double> amount;
  final int pageIndex;
  final Color? backgroundColor;
  final Widget child;
  final bool isRightSwipe;

  @override
  State<PageFlipBuilder> createState() => PageFlipBuilderState();
}

class PageFlipBuilderState extends State<PageFlipBuilder> {
  final _boundaryKey = GlobalKey();

  void _captureImage(Duration timeStamp, int index) async {
    if (_boundaryKey.currentContext == null) return;
    if (!mounted) return; // Check mounted before delay

    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return; // Check again after delay

    try {
      if (mounted && _boundaryKey.currentContext != null) {
        final boundary = _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        if (mounted) {
          setState(() {
            imageData[index] = image.clone();
          });
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentPage,
      builder: (context, value, child) {
        final isCurrent = widget.pageIndex == currentPageIndex.value;
        final isNext = widget.pageIndex == currentPageIndex.value + 1;
        final hasImage = imageData[widget.pageIndex] != null;

        // Content widget - her zaman hazır
        final contentWidget = SizedBox.expand(
          child: ColoredBox(
            color: widget.backgroundColor ?? Colors.black12,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: widget.child,
            ),
          ),
        );

        // Animasyon aktif mi? (value >= 0 ve amount < 1.0)
        final bool isAnimating = value >= 0 && widget.amount.value < 1.0;

        // Page flip animasyonu için image capture
        if (hasImage && isAnimating) {
          // Animasyon sırasında CustomPaint göster
          return CustomPaint(
            painter: PageFlipEffect(
              amount: widget.amount,
              image: imageData[widget.pageIndex]!,
              backgroundColor: widget.backgroundColor,
              isRightSwipe: widget.isRightSwipe,
            ),
            size: Size.infinite,
          );
        } else {
          // Capture image for future animation
          if ((value == widget.pageIndex || value == (widget.pageIndex + 1)) && !hasImage) {
            WidgetsBinding.instance.addPostFrameCallback(
              (timeStamp) => _captureImage(timeStamp, widget.pageIndex),
            );
          }

          // Show current page AND next page (so next page is visible during flip)
          if (isCurrent || isNext) {
            return contentWidget;
          } else {
            // Non-visible pages: use Offstage to keep in tree but invisible
            return Offstage(
              offstage: true,
              child: contentWidget,
            );
          }
        }
      },
    );
  }
}
