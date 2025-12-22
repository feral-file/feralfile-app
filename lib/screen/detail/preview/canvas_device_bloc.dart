//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/device_display_setting.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/int_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/transformers.dart';

abstract class CanvasDeviceEvent {}

class CanvasDeviceUpdateCastingStatusEvent extends CanvasDeviceEvent {
  CanvasDeviceUpdateCastingStatusEvent(
    this.device,
    this.status,
  );

  final BaseDevice device;
  final CheckCastingStatusReply status;
}

class CanvasDeviceRotateEvent extends CanvasDeviceEvent {
  CanvasDeviceRotateEvent(
    this.device, {
    this.clockwise = false,
    this.onDoneCallback,
  });

  final BaseDevice device;
  final bool clockwise;
  final FutureOr<void> Function()? onDoneCallback;
}

class CanvasDeviceUpdateArtFramingEvent extends CanvasDeviceEvent {
  CanvasDeviceUpdateArtFramingEvent(
    this.device,
    this.artFraming,
    this.onErrorCallback,
    this.onDoneCallback,
  );

  final BaseDevice device;
  final ArtFraming artFraming;

  final FutureOr<void> Function(Object error)? onErrorCallback;
  final FutureOr<void> Function()? onDoneCallback;
}

/*
* Version V2
*/

class CanvasDeviceDisconnectedEvent extends CanvasDeviceEvent {
  CanvasDeviceDisconnectedEvent(this.device, {this.callRPC = true});

  final BaseDevice device;
  final bool callRPC;
}

class CanvasDeviceCastDP1PlaylistEvent extends CanvasDeviceEvent {
  CanvasDeviceCastDP1PlaylistEvent({
    required this.device,
    required this.playlist,
    required this.intent,
    this.usingUrl = true,
    this.onDoneCallback,
  });

  final BaseDevice device;
  final DP1Call playlist;
  final DP1Intent intent;
  final bool usingUrl;
  final FutureOr<void> Function()? onDoneCallback;
}

class CanvasDevicePauseCastingEvent extends CanvasDeviceEvent {
  CanvasDevicePauseCastingEvent(this.device);

  final BaseDevice device;
}

class CanvasDeviceResumeCastingEvent extends CanvasDeviceEvent {
  CanvasDeviceResumeCastingEvent(this.device);

  final BaseDevice device;
}

class CanvasDeviceNextArtworkEvent extends CanvasDeviceEvent {
  CanvasDeviceNextArtworkEvent(this.device);

  final BaseDevice device;
}

class CanvasDevicePreviousArtworkEvent extends CanvasDeviceEvent {
  CanvasDevicePreviousArtworkEvent(this.device);

  final BaseDevice device;
}

class CanvasDeviceMoveToArtworkEvent extends CanvasDeviceEvent {
  CanvasDeviceMoveToArtworkEvent(this.device, this.index);

  final BaseDevice device;
  final int index;
}

class CanvasDeviceUpdateDurationEvent extends CanvasDeviceEvent {
  CanvasDeviceUpdateDurationEvent(this.device, this.artwork);

  final BaseDevice device;
  final List<PlayArtworkV2> artwork;
}

class CanvasDeviceUpdateConnectionEvent extends CanvasDeviceEvent {
  CanvasDeviceUpdateConnectionEvent(this.device, this.isConnected);

  final BaseDevice device;
  final bool isConnected;
}

class CanvasDeviceState {
  CanvasDeviceState({
    Map<String, CheckCastingStatusReply>? canvasDeviceStatus,
    Map<String, bool>? deviceAliveMap,
    Map<String, DeviceStatus>? deviceInfoMap,
  })  : canvasDeviceStatus = canvasDeviceStatus ?? {},
        deviceAliveMap = deviceAliveMap ?? {},
        deviceInfoMap = deviceInfoMap ?? {};

  final Map<String, CheckCastingStatusReply> canvasDeviceStatus;
  final Map<String, bool> deviceAliveMap;
  final Map<String, DeviceStatus> deviceInfoMap;

  CanvasDeviceState copyWith({
    Map<String, CheckCastingStatusReply>? controllingDeviceStatus,
    Map<String, bool>? deviceAliveMap,
    Map<String, DeviceStatus>? deviceInfoMap,
  }) =>
      CanvasDeviceState(
        canvasDeviceStatus: controllingDeviceStatus ?? canvasDeviceStatus,
        deviceAliveMap: deviceAliveMap ?? this.deviceAliveMap,
        deviceInfoMap: deviceInfoMap ?? this.deviceInfoMap,
      );

  List<BaseDevice> get devices => BluetoothDeviceManager.pairedDevices;

  CheckCastingStatusReply? statusOf(BaseDevice device) =>
      canvasDeviceStatus[device.deviceId];

  DeviceStatus? deviceInfoOf(BaseDevice device) =>
      deviceInfoMap[device.deviceId];

  bool isDeviceAlive(BaseDevice device) {
    final isAlive = deviceAliveMap[device.deviceId] == true;
    return isAlive;
  }

  CanvasDeviceState updateDeviceAlive(
    BaseDevice device,
    bool isAlive,
  ) {
    final newDeviceAliveMap = deviceAliveMap.copy();
    newDeviceAliveMap[device.deviceId] = isAlive;

    return copyWith(
      deviceAliveMap: newDeviceAliveMap,
    );
  }

  List<BaseDevice> get activeDevices {
    return devices.where(isDeviceAlive).toList();
  }

  DeviceDisplaySetting? deviceDisplaySettingOf(BaseDevice device) {
    final status = statusOf(device);
    return status?.deviceSettings;
  }
}

EventTransformer<Event> debounceSequential<Event>(Duration duration) =>
    (events, mapper) => events.throttleTime(duration).asyncExpand(mapper);

class CanvasDeviceBloc extends AuBloc<CanvasDeviceEvent, CanvasDeviceState> {
  // constructor
  CanvasDeviceBloc(this._canvasClientServiceV2) : super(CanvasDeviceState()) {
    // old event
    on<CanvasDeviceUpdateCastingStatusEvent>(
      (event, emit) {
        final device = event.device;
        final status = event.status;
        final newState = state.canvasDeviceStatus.copy()
          ..[device.deviceId] = status;
        emit(
          state.copyWith(controllingDeviceStatus: newState),
        );
        NowDisplayingManager().updateDisplayingNow();
      },
    );

    on<CanvasDeviceUpdateConnectionEvent>(
      (event, emit) {
        final device = event.device;
        final isConnected = event.isConnected;
        final newState = state.updateDeviceAlive(device, isConnected);
        emit(newState);
        NowDisplayingManager().updateDisplayingNow();
      },
    );

    on<CanvasDeviceRotateEvent>((event, emit) async {
      final device = event.device;
      try {
        await _canvasClientServiceV2.rotateCanvas(
          device,
          clockwise: event.clockwise,
        );
        await event.onDoneCallback?.call();
      } catch (e, s) {
        log.info('CanvasDeviceBloc: error while rotate device: $e', s);
      }
    });

    /*
    * Version V2
    */

    on<CanvasDeviceDisconnectedEvent>((event, emit) async {
      final device = event.device;
      final newState = state.canvasDeviceStatus.copy()..remove(device.deviceId);
      emit(state.copyWith(controllingDeviceStatus: newState));
    });

    on<CanvasDeviceCastDP1PlaylistEvent>((event, emit) async {
      final device = event.device;
      try {
        final ok = await _canvasClientServiceV2.castPlaylist(
          device,
          event.playlist,
          event.intent,
          usingUrl: event.usingUrl,
        );
        log.info('CanvasDeviceBloc: castPlaylist ok: $ok');
      } catch (e) {
        log.info('CanvasDeviceBloc: error while cast playlist: $e');
      } finally {
        event.onDoneCallback?.call();
      }
    });

    on<CanvasDeviceNextArtworkEvent>((event, emit) async {
      final device = event.device;
      try {
        final currentDeviceState = state.devices.firstWhereOrNull(
          (element) => element.deviceId == device.deviceId,
        );
        if (currentDeviceState == null) {
          throw Exception('Device not found');
        }
        await _canvasClientServiceV2.nextArtwork(device);
      } catch (_) {}
    });

    on<CanvasDevicePreviousArtworkEvent>((event, emit) async {
      final device = event.device;
      try {
        final currentDeviceState = state.devices.firstWhereOrNull(
          (element) => element.deviceId == device.deviceId,
        );
        if (currentDeviceState == null) {
          throw Exception('Device not found');
        }

        await _canvasClientServiceV2.previousArtwork(device);
      } catch (_) {}
    });

    on<CanvasDeviceMoveToArtworkEvent>((event, emit) async {
      final device = event.device;
      final index = event.index;
      try {
        await _canvasClientServiceV2.moveToArtwork(device, index: index);
      } catch (_) {}
    });

    on<CanvasDevicePauseCastingEvent>((event, emit) async {
      final device = event.device;
      try {
        final currentDeviceState = state.devices.firstWhereOrNull(
          (element) => element.deviceId == device.deviceId,
        );
        if (currentDeviceState == null) {
          throw Exception('Device not found');
        }
        final currentDeviceStatus = state.canvasDeviceStatus[device.deviceId];
        if (currentDeviceStatus == null) {
          log.info(
            'CanvasDeviceBloc, CanvasDevicePauseCastingEvent currentDeviceStatus is null for device: ${device.deviceId}',
          );
          return;
        }
        await _canvasClientServiceV2.pauseCasting(device);
      } catch (_) {}
    });

    on<CanvasDeviceResumeCastingEvent>((event, emit) async {
      final device = event.device;
      try {
        final currentDeviceState = state.devices.firstWhereOrNull(
          (element) => element.deviceId == device.deviceId,
        );
        if (currentDeviceState == null) {
          throw Exception('Device not found');
        }
        final currentDeviceStatus = state.canvasDeviceStatus[device.deviceId];
        if (currentDeviceStatus == null) {
          log.info(
            'CanvasDeviceBloc, CanvasDeviceResumeCastingEvent currentDeviceStatus is null for device: ${device.deviceId}',
          );
          return;
        }
        await _canvasClientServiceV2.resumeCasting(device);
      } catch (_) {}
    });

    on<CanvasDeviceUpdateDurationEvent>((event, emit) async {
      final device = event.device;
      final artworks = event.artwork;
      try {
        await _canvasClientServiceV2.updateDuration(device, artworks);
      } catch (e) {
        log.info('CanvasDeviceBloc: error while update duration: $e');
      }
    });

    on<CanvasDeviceUpdateArtFramingEvent>((event, emit) async {
      final device = event.device;
      final artFraming = event.artFraming;
      try {
        final ok =
            await _canvasClientServiceV2.updateArtFraming(device, artFraming);
        if (!ok) {
          throw Exception('Failed to update art framing');
        }
        event.onDoneCallback?.call();
      } catch (e) {
        log.info('CanvasDeviceBloc: error while update art framing: $e');
        event.onErrorCallback?.call(e);
      }
    });
  }

  final CanvasClientServiceV2 _canvasClientServiceV2;

  void clear() {
    state.devices.clear();
    state.canvasDeviceStatus.clear();
  }
}
