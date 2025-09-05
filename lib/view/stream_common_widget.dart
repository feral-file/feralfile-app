import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/range_input_formatter.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_svg/svg.dart';
import 'package:rxdart/rxdart.dart';

final speedValues = {
  '1min': const Duration(minutes: 1),
  '2min': const Duration(minutes: 2),
  '5min': const Duration(minutes: 5),
  '10min': const Duration(minutes: 10),
  '15min': const Duration(minutes: 15),
  '30min': const Duration(minutes: 30),
  '1hr': const Duration(hours: 1),
  '4hr': const Duration(hours: 4),
  '12hr': const Duration(hours: 12),
  '24hr': const Duration(hours: 24),
};

class StreamDrawerItem extends StatelessWidget {
  const StreamDrawerItem({
    required this.item,
    required this.backgroundColor,
    required this.isControlling,
    super.key,
    this.onRotateClicked,
  });

  final OptionItem item;
  final Color backgroundColor;
  final Function()? onRotateClicked;
  final bool isControlling;

  static const double rotateIconSize = 22;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColor.primaryBlack,
          borderRadius: BorderRadius.circular(50),
        ),
        width: MediaQuery.of(context).size.width,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  right: isControlling ? (rotateIconSize + 25 + 10) : 0,
                ),
                child: InkWell(
                  splashFactory: InkSparkle.splashFactory,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                textAlign: TextAlign.center,
                                item.title ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .ppMori400Black14,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.icon != null) ...[
                              const SizedBox(width: 10),
                              item.icon!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  onTap: () => item.onTap?.call(),
                ),
              ),
              if (isControlling)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: ResponsiveLayout.paddingHorizontal,
                  child: ColoredBox(
                    color: AppColor.primaryBlack,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: onRotateClicked,
                          child: SvgPicture.asset(
                            'assets/images/icon_rotate.svg',
                            width: rotateIconSize,
                            height: rotateIconSize,
                            colorFilter: const ColorFilter.mode(
                              AppColor.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class PlaylistControl extends StatefulWidget {
  const PlaylistControl({
    required this.displayKey,
    super.key,
    this.viewingArtworkBuilder,
  });

  final String displayKey;
  final Widget Function(BuildContext context, CanvasDeviceState state)?
      viewingArtworkBuilder;

  @override
  State<PlaylistControl> createState() => _PlaylistControlState();
}

class _PlaylistControlState extends State<PlaylistControl> {
  Timer? _timer;
  late CanvasDeviceBloc _canvasDeviceBloc;
  BaseDevice? _controllingDevice;

  @override
  void initState() {
    super.initState();
    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
        bloc: _canvasDeviceBloc,
        builder: (context, state) {
          final activeDevice = BluetoothDeviceManager().castingBluetoothDevice;
          _controllingDevice = activeDevice;
          if (activeDevice == null) {
            return const SizedBox.shrink();
          }
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColor.auGreyBackground,
            ),
            child: Column(
              children: [
                if (widget.viewingArtworkBuilder != null) ...[
                  widget.viewingArtworkBuilder!.call(context, state),
                  const SizedBox(height: 15),
                ],
                _buildPlayControls(context, state),
                const SizedBox(height: 15),
                _buildSpeedControl(context, state),
              ],
            ),
          );
        },
      );

  Widget _buildPlayButton({required String icon, required Function() onTap}) =>
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: AppColor.primaryBlack,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              splashFactory: InkSparkle.splashFactory,
              borderRadius: BorderRadius.circular(5),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: SvgPicture.asset(
                  icon,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildPlayControls(BuildContext context, CanvasDeviceState state) {
    final isPlaying =
        !(state.canvasDeviceStatus[_controllingDevice?.deviceId]?.isPaused ??
            false);
    false;
    return Row(
      children: [
        _buildPlayButton(
          icon: 'assets/images/chevron_left_icon.svg',
          onTap: () => {
            onPrevious(context),
          },
        ),
        const SizedBox(width: 15),
        _buildPlayButton(
          icon: isPlaying
              ? 'assets/images/stream_pause_icon.svg'
              : 'assets/images/stream_play_icon.svg',
          onTap: () => {
            onPauseOrResume(context),
          },
        ),
        const SizedBox(width: 15),
        _buildPlayButton(
          icon: 'assets/images/chevron_right_icon.svg',
          onTap: () => {
            onNext(context),
          },
        ),
      ],
    );
  }

  Widget _buildSpeedControl(BuildContext context, CanvasDeviceState state) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'autoplay_duration'.tr(),
            style: Theme.of(context).textTheme.ppMori400White12,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: AppColor.primaryBlack,
            ),
            child: ArtworkDurationControl(
              duration: state.castingSpeed(widget.displayKey) ??
                  speedValues.values.first,
              displayKey: widget.displayKey,
            ),
          ),
        ],
      );

  void onPrevious(BuildContext context) {
    if (_controllingDevice == null) {
      return;
    }
    _canvasDeviceBloc
        .add(CanvasDevicePreviousArtworkEvent(_controllingDevice!));
  }

  void onNext(BuildContext context) {
    if (_controllingDevice == null) {
      return;
    }
    _canvasDeviceBloc.add(CanvasDeviceNextArtworkEvent(_controllingDevice!));
  }

  void onPause(BuildContext context) {
    if (_controllingDevice == null) {
      return;
    }
    _canvasDeviceBloc.add(CanvasDevicePauseCastingEvent(_controllingDevice!));
  }

  void onResume(BuildContext context) {
    if (_controllingDevice == null) {
      return;
    }
    _canvasDeviceBloc.add(CanvasDeviceResumeCastingEvent(_controllingDevice!));
  }

  void onPauseOrResume(BuildContext context) {
    // final _canvasDeviceBloc = context.read<CanvasDeviceBloc>();
    final isPlaying = !(_canvasDeviceBloc
            .state.canvasDeviceStatus[_controllingDevice?.deviceId]?.isPaused ??
        false);
    if (isPlaying) {
      onPause(context);
    } else {
      onResume(context);
    }
  }
}

class ArtworkDurationControl extends StatefulWidget {
  const ArtworkDurationControl({
    required this.displayKey,
    required this.duration,
    super.key,
  });

  final Duration duration;
  final String displayKey;

  @override
  State<ArtworkDurationControl> createState() => _ArtworkDurationControlState();
}

class _ArtworkDurationControlState extends State<ArtworkDurationControl> {
  late FocusNode dayFocusNode;
  late FocusNode hourFocusNode;
  late FocusNode minFocusNode;
  TextEditingController dayTextController = TextEditingController();
  TextEditingController hourTextController = TextEditingController();
  TextEditingController minTextController = TextEditingController();
  late KeyboardVisibilityController keyboardController;
  StreamSubscription<bool>? _keyboardSubscription;

  late bool isAnyFieldFocused = false;
  final _durationSubject = PublishSubject<Duration>();
  final _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    initDurationController(widget.duration);
    initDurationFocusNode();
    initKeyboardController();
  }

  void initDurationFocusNode() {
    dayFocusNode = FocusNode();
    hourFocusNode = FocusNode();
    minFocusNode = FocusNode();

    dayFocusNode.addListener(_onFocusChanged);
    hourFocusNode.addListener(_onFocusChanged);
    minFocusNode.addListener(_onFocusChanged);
  }

  void initDurationController(Duration duration) {
    int day;
    int hour;
    int min;

    day = duration.inDays;
    hour = duration.inHours % 24;
    min = duration.inMinutes % 60;

    dayTextController.text = day.toString().padLeft(2, '0');
    hourTextController.text = hour.toString().padLeft(2, '0');
    minTextController.text = min.toString().padLeft(2, '0');
  }

  void initKeyboardController() {
    keyboardController = KeyboardVisibilityController();
    _keyboardSubscription = keyboardController.onChange.listen((visible) {
      if (!visible) {
        _onDurationSubmitted();
      }
    });
  }

  void _onFocusChanged() {
    setState(() {
      isAnyFieldFocused = dayFocusNode.hasFocus ||
          hourFocusNode.hasFocus ||
          minFocusNode.hasFocus;
    });
  }

  @override
  Future<void> dispose() async {
    dayFocusNode.dispose();
    hourFocusNode.dispose();
    minFocusNode.dispose();
    dayTextController.dispose();
    hourTextController.dispose();
    minTextController.dispose();
    super.dispose();
    await _keyboardSubscription?.cancel();
    await _durationSubject.close();
  }

  void _changeDurationWithDebounce(Duration duration) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () {
        _changeSpeed(duration);
      },
    );
  }

  void _changeSpeed(Duration duration) {
    final lastSelectedCanvasDevice = _canvasDeviceBloc.state
        .lastSelectedActiveDeviceForKey(widget.displayKey);
    if (lastSelectedCanvasDevice == null) {
      return;
    }
    final canvasStatus =
        _canvasDeviceBloc.state.statusOf(lastSelectedCanvasDevice);
    if (canvasStatus == null) {
      return;
    }
    final playArtworks = canvasStatus.artworks;
    final playArtworkWithNewDuration = playArtworks
        .map(
          (e) =>
              e.copy(duration: Duration(milliseconds: duration.inMilliseconds)),
        )
        .toList();
    _canvasDeviceBloc.add(
      CanvasDeviceUpdateDurationEvent(
        lastSelectedCanvasDevice,
        playArtworkWithNewDuration,
      ),
    );
  }

  void _revertToOldDuration() {
    final lastSelectedCanvasDevice = _canvasDeviceBloc.state
        .lastSelectedActiveDeviceForKey(widget.displayKey);
    if (lastSelectedCanvasDevice == null) {
      return;
    }
    final canvasStatus =
        _canvasDeviceBloc.state.statusOf(lastSelectedCanvasDevice);
    if (canvasStatus == null) {
      return;
    }
    final playArtworks = canvasStatus.artworks;
    if (playArtworks.isEmpty) {
      return;
    }
    final duration = playArtworks.first.duration;
    initDurationController(duration);
  }

  void _onDurationSubmitted() {
    final duration = Duration(
      days: int.tryParse(dayTextController.text) ?? 0,
      hours: int.tryParse(hourTextController.text) ?? 0,
      minutes: int.tryParse(minTextController.text) ?? 0,
    );
    // if duration is valid, reset to new duration
    if (duration.inMilliseconds > 0) {
      _changeDurationWithDebounce(duration);
    }
    // if duration is zero, reset to old duration
    if (duration.inMilliseconds == 0) {
      _revertToOldDuration();
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _durationWidget(
            suffixText: 'Days',
            focusNode: dayFocusNode,
            textController: dayTextController,
            onValueChanged: (value) {
              final dayFormatted = value.toString().padLeft(2, '0');
              dayTextController.text = dayFormatted;
            },
          ),
          _durationWidget(
            suffixText: 'Hours',
            maxValue: 23,
            focusNode: hourFocusNode,
            textController: hourTextController,
            onValueChanged: (value) {
              final hourFormatted = value.toString().padLeft(2, '0');
              hourTextController.text = hourFormatted;
            },
          ),
          _durationWidget(
            suffixText: 'Mins',
            maxValue: 59,
            focusNode: minFocusNode,
            textController: minTextController,
            onValueChanged: (value) {
              final minuteFormatted = value.toString().padLeft(2, '0');
              minTextController.text = minuteFormatted;
            },
          ),
        ],
      );

  Widget _durationWidget({
    required String suffixText,
    required Function(int value) onValueChanged,
    required FocusNode focusNode,
    required TextEditingController textController,
    Function(int value)? onSubmitted,
    int? maxValue,
  }) {
    final textStyle = isAnyFieldFocused && !focusNode.hasFocus
        ? Theme.of(context).textTheme.ppMori400Grey12
        : Theme.of(context).textTheme.ppMori400White12;

    return IntrinsicWidth(
      child: TextField(
        enableInteractiveSelection: false,
        controller: textController,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        style: textStyle,
        cursorWidth: 1,
        decoration: InputDecoration(
          hintText: '00',
          hintStyle: textStyle,
          isCollapsed: true,
          isDense: true,
          border: InputBorder.none,
          suffixIcon: Container(
            margin: const EdgeInsets.only(left: 8, top: 1),
            child: Text(
              suffixText,
              style: textStyle,
            ),
          ),
          suffixIconConstraints: const BoxConstraints(),
        ),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          RangeTextInputFormatter(min: 0, max: maxValue),
        ],
        onTapOutside: (event) => focusNode.unfocus(),
        onChanged: (value) {
          onValueChanged(int.tryParse(value) ?? 0);
        },
        onSubmitted: (value) {
          onSubmitted?.call(int.tryParse(value) ?? 0);
        },
      ),
    );
  }
}

extension PlayArtworkExt on PlayArtworkV2 {
  PlayArtworkV2 copy({
    CastAssetToken? token,
    CastArtwork? artwork,
    Duration? duration,
  }) =>
      PlayArtworkV2(
        token: token ?? this.token,
        artwork: artwork ?? this.artwork,
        duration: duration ?? this.duration,
      );
}
