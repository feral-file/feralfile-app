import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

extension ColorExtension on ThemeData {
  Color get disableColor {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return isLightMode ? AppColor.disabledColor : AppColor.disabledColor;
  }

  Color get auLightGrey {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return isLightMode ? AppColor.auLightGrey : AppColor.auLightGrey;
  }

  Color get auGreyBackground {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return isLightMode ? AppColor.auGreyBackground : AppColor.auGreyBackground;
  }

  Color get auQuickSilver {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return isLightMode ? AppColor.auQuickSilver : AppColor.auQuickSilver;
  }
}
