import 'package:flutter/material.dart';

class TaperedProgressPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double containerHeight;

  TaperedProgressPainter({
    required this.color,
    required this.progress,
    required this.containerHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    final radius = containerHeight / 2; // Full rounded start
    final taperAmount = containerHeight * 0.35; // How much to taper at the end

    // Start from left with rounded corner
    path.moveTo(radius, 0);

    // Top line to the right edge
    path.lineTo(size.width, 0);

    // Taper down on the right edge
    path.lineTo(size.width, taperAmount);

    // Bottom taper
    path.lineTo(size.width, size.height - taperAmount);

    // Bottom line back to left
    path.lineTo(radius, size.height);

    // Left rounded corner (bottom-left arc)
    path.arcToPoint(
      Offset(0, size.height - radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );

    // Left edge
    path.lineTo(0, radius);

    // Left rounded corner (top-left arc)
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.circular(radius),
      clockwise: false,
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TaperedProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
