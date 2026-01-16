import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:get/get.dart';
import 'font_size_controls.dart';
import 'brightness_slider.dart';
import 'theme_grid.dart';

Future updateFontSettings({
  required BuildContext context,
  required Color backColor,
  required Color fontColor,
  required double brightnessLevel,
  required int staticThemeId,
  required Function(double) setBrightness,
  required Function(int id, {bool? forceDarkMode}) updateTheme,
  required double fontSizeProgress,
  required Function(double) onFontSizeChange,
}) {
  return showModalBottomSheet(
    context: context,
    elevation: 10,
    clipBehavior: Clip.antiAlias,
    backgroundColor: Get.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
    enableDrag: true,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20.r),
        topRight: Radius.circular(20.r),
      ),
    ),
    builder: (context) {
      double localFontSize = fontSizeProgress;

      return StatefulBuilder(
        builder: (BuildContext context, setState) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CosmosEpubLocalization.t('themes'),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Get.isDarkMode ? fontColor.withOpacity(.8) : Colors.black,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2), // background color
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6), // adjust size of the circle
                        child: Icon(
                          Icons.close,
                          color: Get.isDarkMode ? fontColor.withOpacity(.6) : Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                // Font Size Controls
                FontSizeControls(
                  fontColor: fontColor,
                  fontSizeProgress: localFontSize,
                  onFontSizeChange: (newSize) {
                    setState(() {
                      localFontSize = newSize;
                    });
                    onFontSizeChange(newSize);
                  },
                  staticThemeId: staticThemeId,
                  updateTheme: updateTheme,
                ),

                // Brightness slider
                BrightnessSlider(
                  fontColor: fontColor,
                  backColor: backColor,
                  brightnessLevel: brightnessLevel,
                  onBrightnessChanged: (value) {
                    setState(() {
                      brightnessLevel = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    await ScreenBrightness().setScreenBrightness(value);
                  },
                ),

                ThemeGrid(
                  staticThemeId: staticThemeId,
                  updateTheme: updateTheme,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
