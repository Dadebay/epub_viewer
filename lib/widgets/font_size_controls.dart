import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class FontSizeControls extends StatelessWidget {
  final Color fontColor;
  final double fontSizeProgress;
  final Function(double) onFontSizeChange;
  final int staticThemeId;
  final Function(int id, {bool? forceDarkMode}) updateTheme;

  const FontSizeControls({
    super.key,
    required this.fontColor,
    required this.fontSizeProgress,
    required this.onFontSizeChange,
    required this.staticThemeId,
    required this.updateTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              height: 43.h,
              // padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  _fontButton(context, "A", 16.sp, -1),
                  Container(
                      width: 1,
                      height: 30.h,
                      color: Colors.grey.withOpacity(0.3)),
                  _fontButton(context, "A", 22.sp, 1),
                ],
              ),
            ),
          ),
          Container(
            width: 60.w,
            height: 43.h,
            margin: EdgeInsets.only(left: 16.w),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: IconButton(
              icon: Icon(
                Get.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color:
                    Get.isDarkMode ? fontColor.withOpacity(.6) : Colors.black,
                size: 20.sp,
              ),
              onPressed: () {
                // Determine target dark mode state (opposite of current)
                final targetDarkMode = !Get.isDarkMode;

                // Change GetX theme mode
                Get.changeThemeMode(
                    targetDarkMode ? ThemeMode.dark : ThemeMode.light);

                // Apply theme immediately with forced dark mode value
                updateTheme(staticThemeId, forceDarkMode: targetDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontButton(
      BuildContext context, String label, double size, int direction,
      {bool isDisabled = false}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        splashColor:
            isDisabled ? Colors.transparent : Colors.grey.withOpacity(0.3),
        highlightColor:
            isDisabled ? Colors.transparent : Colors.grey.withOpacity(0.1),
        onTap: isDisabled
            ? null
            : () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const LoadingWidget(
                      height: 150,
                      animationWidth: 80,
                      animationHeight: 80,
                    );
                  },
                );

                double newSize = fontSizeProgress + (direction * 2);
                newSize = newSize.clamp(10.0, 24.0);

                // Log font size change
                print(
                    '═══════════════════════════════════════════════════════');
                print('🔤 FONT SIZE CHANGED');
                print('Previous: ${fontSizeProgress}px → New: ${newSize}px');
                print(
                    'Direction: ${direction > 0 ? "Increase +" : "Decrease -"}');
                print(
                    '═══════════════════════════════════════════════════════');

                onFontSizeChange(newSize);

                // Small delay to ensure loading is visible and UI has time to process
                await Future.delayed(const Duration(milliseconds: 500));

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
        child: Container(
          height: 40.h,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: size,
              color: isDisabled
                  ? Colors.grey.withOpacity(0.4)
                  : (Get.isDarkMode ? fontColor.withOpacity(.6) : Colors.black),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
