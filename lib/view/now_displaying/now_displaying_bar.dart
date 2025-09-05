import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/model/error/now_displaying_error.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/collapsed_now_playing_bar.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/expanded_now_playing_bar.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/status_bar.dart';
import 'package:flutter/material.dart';

final double kNowDisplayingHeight =
    NowPlayingBarTokens.collapseHeight.toDouble();

class NowDisplayingBar extends StatefulWidget {
  const NowDisplayingBar({super.key});

  @override
  State<NowDisplayingBar> createState() => _NowDisplayingBarState();
}

class _NowDisplayingBarState extends State<NowDisplayingBar>
    with AfterLayoutMixin<NowDisplayingBar> {
  final NowDisplayingManager _manager = NowDisplayingManager();
  late NowDisplayingStatus nowDisplayingStatus;

  @override
  void initState() {
    super.initState();
    nowDisplayingStatus = _manager.nowDisplayingStatus;
    _manager.nowDisplayingStream.listen(
      (status) {
        if (mounted) {
          setState(
            () {
              nowDisplayingStatus = status;
              if (status is! NowDisplayingSuccess) {
                isNowDisplayingBarExpanded.value = false;
              }
            },
          );
        }
      },
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {}

  @override
  Widget build(BuildContext context) {
    switch (nowDisplayingStatus.runtimeType) {
      case NoDevicePaired:
        return _noDeviceView(context);
      case DeviceDisconnected:
        return _connectFailedView(context, nowDisplayingStatus);
      case ConnectionLost:
        return _connectionLostView(
          context,
          nowDisplayingStatus,
        );
      case NowDisplayingError:
        return _getNowDisplayingErrorView(context, nowDisplayingStatus);
      case NowDisplayingSuccess:
        final nowPlayingObject =
            (nowDisplayingStatus as NowDisplayingSuccess).object;
        if (nowPlayingObject is! DP1NowDisplayingObject) {
          return const SizedBox();
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: NowPlayingBarTokens.expandedHeight.toDouble(),
          ),
          child: TwoStopDraggableSheet(
            key: draggableSheetKey,
            minSize: NowPlayingBarTokens.collapseHeight /
                NowPlayingBarTokens.expandedHeight,
            maxSize: 1,
            collapsedBuilder: (context, scrollController) {
              return CollapsedNowPlayingBar(
                playingObject: nowPlayingObject,
              );
            },
            expandedBuilder:
                (BuildContext context, ScrollController scrollController) {
              return ExpandedNowPlayingBar(
                playingObject: nowPlayingObject,
              );
            },
          ),
        );

      default:
        return const SizedBox();
    }
  }

  Widget _connectFailedView(BuildContext context, NowDisplayingStatus status) {
    final device = (status as DeviceDisconnected).device;
    final deviceName =
        device.name.isNotEmpty == true ? device.name : 'Portal (FF-X1)';
    return NowPlayingStatusBar(
      status: 'Device $deviceName is offline or disconnected.',
    );
  }

  Widget _connectionLostView(
    BuildContext context,
    NowDisplayingStatus status,
  ) {
    final device = (status as ConnectionLost).device;
    final deviceName =
        device.name.isNotEmpty == true ? device.name : 'Portal (FF-X1)';
    return NowPlayingStatusBar(
      status: 'Connection to $deviceName lost.',
    );
  }

  Widget _getNowDisplayingErrorView(
    BuildContext context,
    NowDisplayingStatus nowDisplayingStatus,
  ) {
    final error = (nowDisplayingStatus as NowDisplayingError).error;

    if (error is CheckCastingStatusException) {
      return NowPlayingStatusBar(
        status: error.error.message,
      );
    }

    return NowPlayingStatusBar(
      status: error.toString(),
    );
  }

  // there no device setuped
  Widget _noDeviceView(BuildContext context) {
    return const NowPlayingStatusBar(
      status:
          'Pair an FF1 to display your collection and curated art on any screen.',
    );
  }
}
