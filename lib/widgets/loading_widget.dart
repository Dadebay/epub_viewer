import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingWidget extends StatelessWidget {
  final double? height;
  final double? width;
  final double? animationWidth;
  final double? animationHeight;
  final String? animationPath;

  const LoadingWidget({
    super.key,
    this.height = 220,
    this.width,
    this.animationWidth = 100,
    this.animationHeight = 100,
    this.animationPath = 'assets/animations/loading2.json',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Center(
        child: Lottie.asset(
          animationPath!,
          width: animationWidth,
          height: animationHeight,
          fit: BoxFit.contain,
          package: 'cosmos_epub',
        ),
      ),
    );
  }
}
