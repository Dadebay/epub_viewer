import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../components/constants.dart';

/// Theme configuration data class
class EpubThemeConfig {
  final Color backColor;
  final Color fontColor;
  final Color buttonBackgroundColor;
  final Color buttonIconColor;
  final String selectedFont;
  final String selectedTextStyle;

  const EpubThemeConfig({
    required this.backColor,
    required this.fontColor,
    required this.buttonBackgroundColor,
    required this.buttonIconColor,
    required this.selectedFont,
    required this.selectedTextStyle,
  });
}

/// Helper class for EPUB theme and font settings
class EpubThemeHelper {
  final GetStorage gs;
  final BuildContext context;

  EpubThemeHelper({
    required this.gs,
    required this.context,
  });

  /// Load theme settings from storage
  Map<String, dynamic> loadThemeSettings(String selectedFont) {
    String font = gs.read(libFont) ?? selectedFont;
    int themeId = gs.read(libTheme) ?? 1; // Default to theme 1
    double fontSize = gs.read(libFontSize) ?? 12.0;

    return {
      'selectedFont': font,
      'themeId': themeId,
      'fontSize': fontSize,
    };
  }

  /// Get theme configuration based on theme ID and dark mode
  /// Returns an EpubThemeConfig with all theme colors and fonts
  static EpubThemeConfig getThemeConfig(int id, {bool? forceDarkMode}) {
    log('theme id $id');
    bool isDarkMode = forceDarkMode ?? Get.isDarkMode;
    log('isDarkMode: $isDarkMode (forced: ${forceDarkMode != null})');

    Color backColor;
    Color fontColor;
    Color buttonBackgroundColor;
    Color buttonIconColor;
    String selectedFont;
    String selectedTextStyle;

    if (id == 1) {
      backColor = isDarkMode ? const Color(0xFF000000) : Colors.white;
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
      buttonBackgroundColor = isDarkMode ? const Color(0xff1f1f21) : const Color(0xFFEAEAEB);
      buttonIconColor = isDarkMode ? const Color(0xFFEAEAEB) : const Color(0xFF252527);
      selectedFont = 'SFPro';
      selectedTextStyle = 'SFPro';
    } else if (id == 2) {
      backColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFF4a4a4c);
      fontColor = isDarkMode ? const Color(0xFFABAAB2) : const Color(0xFFABAAB2);
      buttonBackgroundColor = isDarkMode ? const Color(0xff1f1f21) : const Color(0xFF505052);
      buttonIconColor = const Color(0xFFEAEAEB);
      selectedFont = 'NewYork';
      selectedTextStyle = 'NewYork';
    } else if (id == 3) {
      backColor = isDarkMode ? const Color(0xFF1c1c1e) : const Color(0xFFf0eced);
      fontColor = isDarkMode ? const Color(0xFFf2f2f0) : const Color(0xFF211C1D);
      buttonBackgroundColor = isDarkMode ? const Color(0xff1f1f21) : const Color(0xFFd5d1d3);
      buttonIconColor = isDarkMode ? const Color(0xFFEAEAEB) : const Color(0xFF252527);
      selectedFont = 'NewYork';
      selectedTextStyle = 'NewYork';
    } else if (id == 4) {
      backColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
      buttonBackgroundColor = isDarkMode ? const Color(0xff1f1f21) : const Color(0xFFeeeff0);
      buttonIconColor = isDarkMode ? const Color(0xFFEAEAEB) : const Color(0xFF252527);
      selectedFont = 'SFPro';
      selectedTextStyle = 'SFPro';
    } else if (id == 5) {
      backColor = isDarkMode ? const Color(0xFF423c30) : const Color(0xFFf4e8d6);
      fontColor = isDarkMode ? const Color(0xFFD9C5B2) : const Color(0xFF3E3329);
      buttonBackgroundColor = isDarkMode ? const Color(0xff514c44) : const Color(0xFFdbd1c2);
      buttonIconColor = isDarkMode ? const Color(0xFFfafafa) : const Color(0xFF3E3329);
      selectedFont = 'NewYork';
      selectedTextStyle = 'NewYork';
    } else {
      backColor = isDarkMode ? const Color(0xFF18160d) : const Color(0xFFfffcf4);
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF151102);
      buttonBackgroundColor = isDarkMode ? const Color(0xFF3b3933) : const Color(0xFFEAEAEB);
      buttonIconColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF252527);
      selectedFont = 'NewYork';
      selectedTextStyle = 'NewYork';
    }

    return EpubThemeConfig(
      backColor: backColor,
      fontColor: fontColor,
      buttonBackgroundColor: buttonBackgroundColor,
      buttonIconColor: buttonIconColor,
      selectedFont: selectedFont,
      selectedTextStyle: selectedTextStyle,
    );
  }

  /// Save theme preference to storage
  void saveThemePreference(int id, String selectedFont) {
    gs.write(libTheme, id);
    gs.write(libFont, selectedFont);
  }

  /// Build theme selection card widget
  static Widget buildThemeCard({
    required int id,
    required String title,
    required Color backgroundColor,
    required Color textColor,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Save font size to storage
  void saveFontSize(double fontSize) {
    gs.write(libFontSize, fontSize);
  }

  /// Save selected font to storage
  void saveFont(String fontName) {
    gs.write(libFont, fontName);
  }

  /// Get theme definitions for the theme selector (with dark mode support)
  static List<Map<String, dynamic>> getThemeDefinitions() {
    return [
      {
        'id': 1,
        'title': 'Classic',
        'lightBg': Colors.white,
        'lightText': const Color(0xFF000000),
        'darkBg': const Color(0xFF000000),
        'darkText': const Color(0xFFFFFFFF),
      },
      {
        'id': 2,
        'title': 'Dark Gray',
        'lightBg': const Color(0xFF4a4a4c),
        'lightText': const Color(0xFFABAAB2),
        'darkBg': const Color(0xFF000000),
        'darkText': const Color(0xFFABAAB2),
      },
      {
        'id': 3,
        'title': 'Elegant',
        'lightBg': const Color(0xFFf0eced),
        'lightText': const Color(0xFF211C1D),
        'darkBg': const Color(0xFF1c1c1e),
        'darkText': const Color(0xFFf2f2f0),
      },
      {
        'id': 4,
        'title': 'Modern',
        'lightBg': const Color(0xFFFFFFFF),
        'lightText': const Color(0xFF1C1C1E),
        'darkBg': const Color(0xFF000000),
        'darkText': const Color(0xFFFFFFFF),
      },
      {
        'id': 5,
        'title': 'Sepia',
        'lightBg': const Color(0xFFf4e8d6),
        'lightText': const Color(0xFF3E3329),
        'darkBg': const Color(0xFF423c30),
        'darkText': const Color(0xFFD9C5B2),
      },
      {
        'id': 6,
        'title': 'Warm',
        'lightBg': const Color(0xFFfffcf4),
        'lightText': const Color(0xFF151102),
        'darkBg': const Color(0xFF18160d),
        'darkText': const Color(0xFFFFFFFF),
      },
    ];
  }

  /// Get theme data for specific theme ID (simple version without dark mode)
  static Map<String, dynamic> getThemeData(int id) {
    final themes = getThemeDefinitions();
    final theme = themes.firstWhere((t) => t['id'] == id, orElse: () => themes.first);
    bool isDark = Get.isDarkMode;
    return {
      'title': theme['title'],
      'backgroundColor': isDark ? theme['darkBg'] : theme['lightBg'],
      'textColor': isDark ? theme['darkText'] : theme['lightText'],
    };
  }
}
