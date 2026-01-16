import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ThemeCard extends StatelessWidget {
  final int id;
  final String title;
  final bool isSelected;
  final Color backgroundColor;
  final Color textColor;
  final Function(int) updateTheme;

  const ThemeCard({
    super.key,
    required this.id,
    required this.title,
    required this.isSelected,
    required this.backgroundColor,
    required this.textColor,
    required this.updateTheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => updateTheme(id),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? Colors.grey.shade400 : Colors.grey.shade300,
            width: isSelected ? 3 : 2,
          ),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 40.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
