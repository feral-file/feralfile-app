import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class NowDisplaySettingView extends StatefulWidget {
  const NowDisplaySettingView({
    this.artistName,
    this.tokenConfiguration,
    this.tokenId,
    super.key,
  });

  final String? artistName;
  final ArtistDisplaySetting? tokenConfiguration;
  final String? tokenId;
  @override
  State<NowDisplaySettingView> createState() => _NowDisplaySettingViewState();
}

class _NowDisplaySettingViewState extends State<NowDisplaySettingView> {
  late ArtFraming selectedFitment;
  late FFBluetoothDevice? connectedDevice;
  bool overridable = true;

  @override
  void initState() {
    super.initState();
    if (widget.tokenId != null) {
      initDisplaySettings();
    }

    connectedDevice = BluetoothDeviceManager().castingBluetoothDevice;
  }

  void initDisplaySettings() {
    overridable = widget.tokenConfiguration?.overridable ?? true;
    if (overridable) {
      final castingDevice = BluetoothDeviceManager().castingBluetoothDevice;
      final deviceStatus =
          injector<CanvasDeviceBloc>().state.statusOf(castingDevice!);
      selectedFitment = deviceStatus?.deviceSettings?.scaling ??
          widget.tokenConfiguration?.artFraming ??
          ArtFraming.fitToScreen;
    } else {
      // Use artist's settings when not overridable
      selectedFitment = widget.tokenConfiguration!.artFraming;
    }
  }

  Future<void> _updateFitment(ArtFraming fitment) async {
    if (fitment == selectedFitment) {
      return;
    }

    if (connectedDevice == null) {
      log.warning(
        'NowDisplaySetting: fitmentOption: connectedDevice is null',
      );
      return;
    }

    try {
      unawaited(
        injector<CanvasClientServiceV2>().updateArtFraming(
          connectedDevice!,
          fitment,
        ),
      );
      setState(() {
        selectedFitment = fitment;
      });
    } catch (e) {
      log.warning(
        'NowDisplaySetting: updateDisplaySettings error: $e',
      );
    }
  }

  OptionItem fitmentOption(ArtFraming fitment) {
    return OptionItem(
      title: fitment == ArtFraming.fitToScreen ? 'fit'.tr() : 'fill'.tr(),
      icon: SvgPicture.asset(
        fitment == selectedFitment
            ? 'assets/images/radio_selected.svg'
            : 'assets/images/radio_unselected.svg',
      ),
      onTap: () async {
        await _updateFitment(fitment);
      },
    );
  }

  OptionItem restoreSettingsOption() {
    return OptionItem(
      builder: (context, item) {
        return GestureDetector(
          onTap: () async {
            final tokenConfig = widget.tokenConfiguration;
            if (tokenConfig == null) {
              return;
            }
            final fitment = tokenConfig.artFraming;
            await _updateFitment(fitment);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColor.white),
              borderRadius: BorderRadius.circular(47),
            ),
            child: Center(
              child: Text(
                'restore_artist_preference'.tr(),
                style: Theme.of(context).textTheme.ppMori400White14,
              ),
            ),
          ),
        );
      },
    );
  }

  List<OptionItem> _settingOptions() {
    return overridable
        ? [
            OptionItem(
              title: 'Rotate',
              icon: SvgPicture.asset(
                'assets/images/icon_rotate_white.svg',
              ),
              onTap: () async {
                if (connectedDevice == null) {
                  log.warning(
                    'NowDisplaySetting: fitmentOption: connectedDevice is null',
                  );
                  return;
                }

                try {
                  await injector<CanvasClientServiceV2>()
                      .rotateCanvas(connectedDevice!);
                } catch (e) {
                  log.warning(
                    'NowDisplaySetting: updateDisplaySettings error: $e',
                  );
                }
              },
            ),
            if (widget.tokenId != null) ...[
              fitmentOption(ArtFraming.fitToScreen),
              fitmentOption(ArtFraming.cropToFill),
              if (widget.tokenConfiguration != null) restoreSettingsOption(),
            ],
            OptionItem.emptyOptionItem,
          ]
        : [];
  }

  Widget _artistPreferenceNote() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        13,
        0,
        13,
        overridable ? 0 : 40,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColor.feralFileLightBlue,
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                overridable
                    ? 'assets/images/unlock_icon.svg'
                    : 'assets/images/lock_icon.svg',
                height: 12,
              ),
              const SizedBox(width: 10),
              Text(
                'artist_display_preference'.tr(),
                style: Theme.of(context).textTheme.ppMori700Black14,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            (overridable
                    ? 'artist_display_preference_unlock_desc'.tr()
                    : 'artist_display_preference_lock_desc'.tr())
                .replaceAll(
              'artist_name',
              widget.artistName ?? 'Artist',
            ),
            style: Theme.of(context).textTheme.ppMori400Black14,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (connectedDevice == null) {
      return const SizedBox.shrink();
    }
    final shouldShowArtistPreferenceNote = widget.tokenConfiguration != null;
    final itemCount =
        _settingOptions().length + (shouldShowArtistPreferenceNote ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0 && shouldShowArtistPreferenceNote) {
              return _artistPreferenceNote();
            }

            final option = _settingOptions()[
                index - (shouldShowArtistPreferenceNote ? 1 : 0)];
            if (option.builder != null) {
              return option.builder!.call(context, option);
            }
            return DrawerItem(
              item: option,
              color: AppColor.white,
            );
          },
          itemCount: itemCount,
          separatorBuilder: (context, index) =>
              (index == 0 && shouldShowArtistPreferenceNote ||
                      index == itemCount - 1)
                  ? const SizedBox()
                  : const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColor.primaryBlack,
                    ),
        ),
      ],
    );
  }
}
