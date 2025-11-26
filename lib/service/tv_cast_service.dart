import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/tv_cast_api.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:dio/dio.dart';
import 'package:sentry/sentry_io.dart';

abstract class TvCastService {
  Future<CheckCastingStatusReply> status(
    CheckCastingStatusRequest request, {
    bool shouldShowError = true,
  });

  Future<ConnectReplyV2> connect(ConnectRequestV2 request);

  Future<DisconnectReplyV2> disconnect(DisconnectRequestV2 request);

  Future<CastListArtworkReply> castListArtwork(CastListArtworkRequest request);

  Future<PauseCastingReply> pauseCasting(PauseCastingRequest request);

  Future<ResumeCastingReply> resumeCasting(ResumeCastingRequest request);

  Future<NextArtworkReply> nextArtwork(NextArtworkRequest request);

  Future<PreviousArtworkReply> previousArtwork(PreviousArtworkRequest request);

  Future<UpdateDurationReply> updateDuration(UpdateDurationRequest request);

  Future<KeyboardEventReply> keyboardEvent(KeyboardEventRequest request);

  Future<RotateReply> rotate(RotateRequest request);

  Future<SendLogReply> getSupport(SendLogRequest request);

  Future<GetDeviceStatusReply> getDeviceStatus(
    GetDeviceStatusRequest request,
  );

  Future<UpdateArtFramingReply> updateArtFraming(
    UpdateArtFramingRequest request,
  );

  Future<UpdateDisplaySettingsReply> updateDisplaySettings(
    UpdateDisplaySettingsRequest request,
  );

  Future<UpdateToLatestVersionReply> updateToLatestVersion(
    UpdateToLatestVersionRequest request,
  );

  Future<CastExhibitionReply> castExhibition(CastExhibitionRequest request);

  Future<CastDailyWorkReply> castDailyWork(CastDailyWorkRequest request);

  Future<GestureReply> tap(TapGestureRequest request);

  Future<GestureReply> drag(DragGestureRequest request);

  Future<ShowPairingQRCodeReply> showPairingQRCode(
    ShowPairingQRCodeRequest request,
  );

  Future<void> safeShutdown(
    SafeShutdownRequest request,
  );

  Future<DeviceRealtimeMetricsReply> deviceMetrics(
    DeviceRealtimeMetricsRequest request,
  );
}

abstract class BaseTvCastService implements TvCastService {
  BaseTvCastService();

  Future<Map<String, dynamic>> _sendData(
    Map<String, dynamic> body, {
    bool shouldShowError = true,
    Duration? timeout,
  });

  Map<String, dynamic> _getBody(Request request) =>
      RequestBody(request).toJson();

  @override
  Future<CheckCastingStatusReply> status(
    CheckCastingStatusRequest request, {
    bool shouldShowError = true,
  }) async {
    try {
      final result = await _sendData(_getBody(request),
          shouldShowError: shouldShowError,
          timeout: const Duration(seconds: 10));
      // return _mapStatusReply(result);
      return CheckCastingStatusReply.fromJson(result);
    } catch (e) {
      log.info('Failed to get device status: $e');
      rethrow;
    }
  }

  CheckCastingStatusReply _mapStatusReply(
    Map<String, dynamic> result,
  ) {
    final state = result['state'];
    DeviceInfoV2? connectedDevice;
    final connectedDeviceJson = state['device'];
    if (connectedDeviceJson != null) {
      final deviceName = connectedDeviceJson['name'] as String;
      final deviceId = connectedDeviceJson['id'] as String;
      connectedDevice = DeviceInfoV2(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: null,
      );
    }
    if (state['command'] == null) {
      return CheckCastingStatusReply(
        artworks: [],
        connectedDevice: connectedDevice,
      );
    }
    final commandJson = Map<String, dynamic>.from(state['command'] as Map);
    final commandString = commandJson['Command'] as String;
    final command = CastCommand.fromString(commandString);
    log.info('[_mapStatusReply] command: $commandString');
    switch (command) {
      case CastCommand.castListArtwork:
        final request = CastListArtworkRequest.fromJson(commandJson);
        return CheckCastingStatusReply(
          artworks: request.artworks,
          connectedDevice: connectedDevice,
        );
      case CastCommand.castDaily:
        return CheckCastingStatusReply(
          artworks: [],
          connectedDevice: connectedDevice,
          displayKey: CastDailyWorkRequest.displayKey,
        );
      case CastCommand.castExhibition:
        final request = CastExhibitionRequest.fromJson(commandJson);
        return CheckCastingStatusReply(
          artworks: [],
          connectedDevice: connectedDevice,
          exhibitionId: request.exhibitionId,
          catalog: request.catalog,
          catalogId: request.catalogId,
        );
      default:
        return CheckCastingStatusReply(
          artworks: [],
          connectedDevice: connectedDevice,
        );
    }
  }

  @override
  Future<ConnectReplyV2> connect(ConnectRequestV2 request) async {
    try {
      final result = await _sendData(_getBody(request));
      return ConnectReplyV2.fromJson(result);
    } catch (e) {
      log.info('Failed to connect to device: $e');
      rethrow;
    }
  }

  @override
  Future<DisconnectReplyV2> disconnect(DisconnectRequestV2 request) async {
    final result = await _sendData(_getBody(request));
    return DisconnectReplyV2.fromJson(result);
  }

  @override
  Future<CastListArtworkReply> castListArtwork(
    CastListArtworkRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return CastListArtworkReply.fromJson(result);
  }

  @override
  Future<PauseCastingReply> pauseCasting(PauseCastingRequest request) async {
    final result = await _sendData(_getBody(request));
    return PauseCastingReply.fromJson(result);
  }

  @override
  Future<ResumeCastingReply> resumeCasting(ResumeCastingRequest request) async {
    final result = await _sendData(_getBody(request));
    return ResumeCastingReply.fromJson(result);
  }

  @override
  Future<NextArtworkReply> nextArtwork(NextArtworkRequest request) async {
    final result = await _sendData(_getBody(request));
    return NextArtworkReply.fromJson(result);
  }

  @override
  Future<PreviousArtworkReply> previousArtwork(
    PreviousArtworkRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return PreviousArtworkReply.fromJson(result);
  }

  @override
  Future<UpdateDurationReply> updateDuration(
    UpdateDurationRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return UpdateDurationReply.fromJson(result);
  }

  @override
  Future<KeyboardEventReply> keyboardEvent(KeyboardEventRequest request) async {
    final result = await _sendData(_getBody(request));
    return KeyboardEventReply.fromJson(result);
  }

  @override
  Future<RotateReply> rotate(RotateRequest request) async {
    final result = await _sendData(_getBody(request));
    return RotateReply.fromJson(result);
  }

  @override
  Future<SendLogReply> getSupport(SendLogRequest request) async {
    final result = await _sendData(_getBody(request));
    return SendLogReply.fromJson(result);
  }

  @override
  Future<GetDeviceStatusReply> getDeviceStatus(
    GetDeviceStatusRequest request,
  ) async {
    final result = await _sendData(
      _getBody(request),
      timeout: const Duration(seconds: 15),
      shouldShowError: false,
    );

    return GetDeviceStatusReply.fromJson(result);
  }

  @override
  Future<UpdateArtFramingReply> updateArtFraming(
    UpdateArtFramingRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return UpdateArtFramingReply.fromJson(result);
  }

  @override
  Future<UpdateDisplaySettingsReply> updateDisplaySettings(
    UpdateDisplaySettingsRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return UpdateDisplaySettingsReply.fromJson(result);
  }

  @override
  Future<UpdateToLatestVersionReply> updateToLatestVersion(
    UpdateToLatestVersionRequest request,
  ) async {
    final result = await _sendData(
      _getBody(request),
      timeout: const Duration(seconds: 30),
    );
    return UpdateToLatestVersionReply.fromJson(result);
  }

  @override
  Future<CastExhibitionReply> castExhibition(
    CastExhibitionRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return CastExhibitionReply.fromJson(result);
  }

  @override
  Future<CastDailyWorkReply> castDailyWork(CastDailyWorkRequest request) async {
    try {
      final body = _getBody(request);
      final result = await _sendData(body);
      return CastDailyWorkReply.fromJson(result);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<GestureReply> tap(TapGestureRequest request) async {
    final result = await _sendData(_getBody(request));
    return GestureReply.fromJson(result);
  }

  @override
  Future<GestureReply> drag(DragGestureRequest request) async {
    final result = await _sendData(_getBody(request));
    return GestureReply.fromJson(result);
  }

  @override
  Future<ShowPairingQRCodeReply> showPairingQRCode(
    ShowPairingQRCodeRequest request,
  ) async {
    final result = await _sendData(_getBody(request));
    return ShowPairingQRCodeReply.fromJson(result);
  }

  @override
  Future<void> safeShutdown(SafeShutdownRequest request) async {
    try {
      await _sendData(_getBody(request));
    } catch (e) {
      log.warning('Failed to perform safe shutdown: $e');
      rethrow;
    }
  }

  @override
  Future<DeviceRealtimeMetricsReply> deviceMetrics(
    DeviceRealtimeMetricsRequest request,
  ) async {
    try {
      final result = await _sendData(_getBody(request));
      return DeviceRealtimeMetricsReply.fromJson(result);
    } catch (e) {
      log.info('Failed to get device metrics: $e');
      rethrow;
    }
  }
}

class TvCastServiceImpl extends BaseTvCastService {
  TvCastServiceImpl(this._api, this._device);

  final TvCastApi _api;
  final BaseDevice _device;

  void _handleError(Object error) {
    final context = injector<NavigationService>().context;
    unawaited(Sentry.captureException(error));
    if (error is DioException) {
      if (error.error is FeralfileError) {
        unawaited(
          UIHelper.showTVConnectError(
            context,
            error.error! as FeralfileError,
          ),
        );
      }
    } else {
      unawaited(
        UIHelper.showTVConnectError(
          context,
          FeralfileError(
            StatusCode.badRequest.value,
            'Unknown error: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> _sendData(
    Map<String, dynamic> body, {
    bool shouldShowError = false,
    Duration? timeout,
  }) async {
    try {
      final resultFuture = _api.request(
        topicId: _device.topicId,
        body: body,
      );
      final result = await resultFuture.timeout(
        timeout ?? const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      ).catchError((Object error) {
        if (error is TimeoutException) {
          throw TimeoutException('Request timed out');
        }
        throw error;
      });
      return (result['message'] as Map).cast<String, dynamic>();
    } catch (e) {
      unawaited(Sentry.captureException(e));
      if (shouldShowError) {
        _handleError(e);
      }
      rethrow;
    }
  }
}
