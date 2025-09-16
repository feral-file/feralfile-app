import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/error/now_displaying_error.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry/sentry.dart';

class NowDisplayingManager {
  factory NowDisplayingManager() => _instance;

  NowDisplayingManager._internal();

  static final NowDisplayingManager _instance =
      NowDisplayingManager._internal();

  Timer? _onDisconnectTimer;

  NowDisplayingStatus nowDisplayingStatus = InitialNowDisplayingStatus();
  final StreamController<NowDisplayingStatus> _streamController =
      StreamController.broadcast();

  Stream<NowDisplayingStatus> get nowDisplayingStream =>
      _streamController.stream;

  void _addStatus(NowDisplayingStatus status) {
    log.info('NowDisplayingManager: $status');
    nowDisplayingStatus = status;
    _streamController.add(status);
    _onDisconnectTimer?.cancel();
    if (status is DeviceDisconnected) {
      // _onDisconnectTimer = Timer(const Duration(seconds: 5), () {
      //   shouldShowNowDisplayingOnDisconnect.value = false;
      // });
    } else if (status is ConnectionLost) {
      // _onDisconnectTimer = Timer(const Duration(seconds: 10), () {
      //   shouldShowNowDisplayingOnDisconnect.value = false;
      // });
    } else if (status is NowDisplayingSuccess) {
      shouldShowNowDisplayingOnDisconnect.value = true;
    }
    nowDisplayingVisibility.value = true;
    // injector<NavigationService>().hideDeviceSettings();
  }

  Future<void> updateDisplayingNow({bool addStatusOnError = true}) async {
    try {
      log.info('NowDisplayingManager: updateDisplayingNow');
      final device = BluetoothDeviceManager().castingBluetoothDevice;
      if (device == null) {
        _addStatus(NoDevicePaired());
        return;
      }

      if (device.isAlive == null) {
        return;
      }

      if (!device.isAlive) {
        _addStatus(DeviceDisconnected(device));
        return;
      }

      CheckCastingStatusReply? status;
      try {
        status = injector<CanvasDeviceBloc>().state.statusOf(device);
      } catch (e) {
        log.info(
          'NowDisplayingManager: updateDisplayingNow error: $e, retrying',
        );
      }

      if (status?.ok == false) {
        throw CheckCastingStatusException(status?.error ?? ReplyError.unknown);
      }

      if (status == null) {
        throw Exception('Failed to get Now Displaying');
      }
      final nowDisplaying = await getNowDisplayingObject(status, device);
      if (nowDisplaying == null) {
        final status = NowDisplayingError(
          CannotGetNowDisplayingException(),
        );
        _addStatus(status);
      } else {
        nowDisplayingStatus = NowDisplayingSuccess(nowDisplaying);
        _addStatus(nowDisplayingStatus);
      }
    } catch (e) {
      log.info('NowDisplayingManager: updateDisplayingNow error: $e');
      unawaited(Sentry.captureException(e));
      if (addStatusOnError) {
        _addStatus(NowDisplayingError(e));
      }
    }
  }

  Future<NowDisplayingObjectBase?> getNowDisplayingObject(
    CheckCastingStatusReply status,
    BaseDevice device,
  ) async {
    if (status.items?.isNotEmpty ?? false) {
      // DP1
      final index = status.index!;
      final assetTokens =
          await _fetchAssetTokens(status.items!.map((e) => e.indexId).toList());

      return DP1NowDisplayingObject(
        index: index,
        dp1Items: status.items!,
        assetTokens: assetTokens,
        connectedDevice: device,
      );
    }
    return null;
  }

  Future<List<AssetToken>> _fetchAssetTokens(List<String> tokenIds) async {
    final assetTokens = await injector<NftTokensService>()
        .getManualTokens(indexerIds: tokenIds);
    return assetTokens;
  }
}

abstract class NowDisplayingStatus {}

class InitialNowDisplayingStatus implements NowDisplayingStatus {
  InitialNowDisplayingStatus();
}

class ConnectionLost implements NowDisplayingStatus {
  ConnectionLost(this.device);

  final BaseDevice device;
}

class DeviceDisconnected implements NowDisplayingStatus {
  DeviceDisconnected(this.device);

  final BaseDevice device;
}

// Now displaying
class NowDisplayingSuccess implements NowDisplayingStatus {
  NowDisplayingSuccess(this.object);

  final NowDisplayingObjectBase object;
}

class NowDisplayingError implements NowDisplayingStatus {
  NowDisplayingError(this.error);

  final Object error;
}

class NoDevicePaired implements NowDisplayingStatus {
  NoDevicePaired();
}
