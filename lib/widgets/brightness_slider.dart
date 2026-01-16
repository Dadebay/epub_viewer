import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class BrightnessSlider extends StatefulWidget {
  final Color fontColor;
  final Color backColor;
  final double brightnessLevel;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double>? onChangeEnd;

  const BrightnessSlider({
    super.key,
    required this.fontColor,
    required this.backColor,
    required this.brightnessLevel,
    required this.onBrightnessChanged,
    this.onChangeEnd,
  });

  @override
  _BrightnessSliderState createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<BrightnessSlider> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.brightnessLevel;
  }

  @override
  void didUpdateWidget(covariant BrightnessSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightnessLevel != widget.brightnessLevel) {
      _localValue = widget.brightnessLevel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 24.h, left: 10.w, top: 10, right: 10.w),
      decoration: BoxDecoration(
        // color: widget.backColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // decrease step-by-step (0.1 per tap)
              double newValue = _localValue - 0.1;

              // clamp so it doesn't go below 0
              if (newValue < 0.0) newValue = 0.0;

              setState(() => _localValue = newValue);

              widget.onBrightnessChanged(newValue);
              widget.onChangeEnd?.call(newValue);
            },
            child: Padding(
              padding: EdgeInsets.only(right: 15.w),
              child: Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: Get.isDarkMode ? widget.fontColor.withOpacity(.6) : Colors.black, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 15.0,
                activeTrackColor: Get.isDarkMode ? Color(0xff69696e) : Colors.grey.shade500,
                inactiveTrackColor: Get.isDarkMode ? Color(0xff444448) : Colors.grey.shade300,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0 // Hidden thumb
                    ),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                trackShape: RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: _localValue.clamp(0.0, 1.0),
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  setState(() {
                    _localValue = value;
                  });

                  widget.onBrightnessChanged(value);
                },
                onChangeEnd: (value) {
                  if (widget.onChangeEnd != null) {
                    widget.onChangeEnd!(value);
                  }
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // increase step-by-step (0.1 per tap)
              double newValue = _localValue + 0.1;

              // clamp so it doesn't go above 1.0
              if (newValue > 1.0) newValue = 1.0;

              setState(() => _localValue = newValue);

              widget.onBrightnessChanged(newValue);
              widget.onChangeEnd?.call(newValue);
            },
            child: Padding(
              padding: EdgeInsets.only(left: 15.w),
              child: Icon(
                Icons.wb_sunny_outlined,
                size: 22.sp,
                color: Get.isDarkMode ? widget.fontColor.withOpacity(.6) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
