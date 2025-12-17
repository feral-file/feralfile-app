import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/design/build/components/CommandDot.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BottomSpacing extends StatelessWidget {
  const BottomSpacing({super.key});

  bool _shouldShowExploreBar() {
    if (Environment.enableExploreDev || kDebugMode) {
      return true;
    }

    final appSettingsStorageService =
        injector<AppDataManager>().appSettingsStorageService;
    return appSettingsStorageService.isBetaFeaturesEnabled &&
        appSettingsStorageService.isExploreBarEnabled;
  }

  bool _shouldShowNowDisplayingBar() {
    return BluetoothDeviceManager().castingBluetoothDevice != null;
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const llmInputHeight = LLMTextInputTokens.padding * 2 +
        LLMTextInputTokens.llmPaddingVertical * 2 +
        CommandDotTokens.height;
    const nowDisplayingBarHeight = NowPlayingBarTokens.collapseHeight;

    return ValueListenableBuilder(
      valueListenable: nowDisplayingShowing,
      builder: (context, value, child) {
        double bottomBarHeight = 0;
        bottomBarHeight = _shouldShowNowDisplayingBar()
            ? nowDisplayingBarHeight.toDouble()
            : 0;
        bottomBarHeight +=
            _shouldShowExploreBar() ? llmInputHeight.toDouble() : 0;

        return SizedBox(
          height: paddingBottom +
              (value
                  ? UIConstants.nowDisplayingBarBottomPadding + bottomBarHeight
                  : 0),
        );
      },
    );
  }
}
