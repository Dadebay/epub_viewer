import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';

class ThemeGrid extends StatefulWidget {
  final int staticThemeId;
  final Function(int) updateTheme;

  const ThemeGrid({
    super.key,
    required this.staticThemeId,
    required this.updateTheme,
  });

  @override
  State<ThemeGrid> createState() => _ThemeGridState();
}

class _ThemeGridState extends State<ThemeGrid> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Using Obx to reactively rebuild when language changes
    return Obx(() {
      CosmosEpub.currentLocale; // ensures rebuild when locale changes
      return Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 16.w,
                mainAxisSpacing: 16.h,
                childAspectRatio: 107.w / 90.h,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ThemeCard(
                    id: 1,
                    title: 'Original',
                    isSelected: widget.staticThemeId == 1,
                    backgroundColor: Get.isDarkMode ? Colors.black : Colors.white,
                    textColor: Get.isDarkMode ? Colors.white : Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 2,
                    title: 'Quite',
                    isSelected: widget.staticThemeId == 2,
                    backgroundColor: const Color(0xFF1C1C1E),
                    textColor: Get.isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFFE5E5EA),
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 3,
                    title: 'Paper',
                    isSelected: widget.staticThemeId == 3,
                    backgroundColor: Get.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    textColor: Get.isDarkMode ? Colors.white : Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 4,
                    title: 'Bold',
                    isSelected: widget.staticThemeId == 4,
                    backgroundColor: Get.isDarkMode ? Colors.black : Colors.white,
                    textColor: Get.isDarkMode ? Colors.white : Colors.black,
                    updateTheme: _handleThemeChange,
                    fontWeight: FontWeight.bold,
                  ),
                  ThemeCard(
                    id: 5,
                    title: 'Calm',
                    isSelected: widget.staticThemeId == 5,
                    backgroundColor: Get.isDarkMode ? const Color(0xFF3A2E2A) : const Color(0xFFFBF1E6),
                    textColor: Get.isDarkMode ? const Color(0xFFD9C5B2) : Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 6,
                    title: 'Focus',
                    isSelected: widget.staticThemeId == 6,
                    backgroundColor: Get.isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8F8),
                    textColor: Get.isDarkMode ? Colors.white : Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const LoadingWidget(
                  height: 150,
                  animationWidth: 80,
                  animationHeight: 80,
                ),
              ),
            ),
        ],
      );
    });
  }

  Future<void> _handleThemeChange(int id) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    await widget.updateTheme(id);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class ThemeCard extends StatelessWidget {
  final int id;
  final String title;
  final bool isSelected;
  final Color backgroundColor;
  final Color textColor;
  final Function(int) updateTheme;
  final FontWeight fontWeight;

  const ThemeCard({
    super.key,
    required this.id,
    required this.title,
    required this.isSelected,
    required this.backgroundColor,
    required this.textColor,
    required this.updateTheme,
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
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

        // Update theme
        await updateTheme(id);

        // Close loading dialog if still mounted
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        height: 80.h,
        width: 107.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? Get.isDarkMode
                    ? Color(0xffa6a5a3).withOpacity(.9)
                    : Colors.grey.shade400
                : Get.isDarkMode
                    ? Color(0xffa6a5a3).withOpacity(.4)
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: EdgeInsets.all(12.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: fontWeight,
                color: Get.isDarkMode ? textColor.withOpacity(.6) : textColor,
                height: 1,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Get.isDarkMode ? textColor.withOpacity(.6) : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Color constants
const Color cLightGrayColor = Color(0xFFF5F5F5);
const Color cDarkGrayColor = Color(0xFF3D3D3D);
const Color cCreamColor = Color(0xFFFAF4E8);
const Color cOffWhiteColor = Color(0xFFFFFDF7);
