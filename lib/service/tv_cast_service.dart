import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/tv_cast_api.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call_request.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
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

  Future<Map<String, dynamic>> sendDP1Call(DP1CallRequest request);

  Future<ConnectReplyV2> connect(ConnectRequestV2 request);

  Future<DisconnectReplyV2> disconnect(DisconnectRequestV2 request);

  Future<CastListArtworkReply> castListArtwork(DP1CallRequest request);

  Future<PauseCastingReply> pauseCasting(PauseCastingRequest request);

  Future<ResumeCastingReply> resumeCasting(ResumeCastingRequest request);

  Future<NextArtworkReply> nextArtwork(NextArtworkRequest request);

  Future<PreviousArtworkReply> previousArtwork(PreviousArtworkRequest request);

  Future<MoveToArtworkReply> moveToArtwork(MoveToArtworkRequest request);

  Future<UpdateDurationReply> updateDuration(UpdateDurationRequest request);

  Future<KeyboardEventReply> keyboardEvent(KeyboardEventRequest request);

  Future<RotateReply> rotate(RotateRequest request);

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

  Future<void> safeRestart(
    SafeRestartRequest request,
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

  Map<String, dynamic> _getBody(FF1Request request) =>
      RequestBody(request).toJson();

  @override
  Future<CheckCastingStatusReply> status(
    CheckCastingStatusRequest request, {
    bool shouldShowError = true,
  }) async {
    try {
      final result = await _sendData(
        _getBody(request),
        shouldShowError: shouldShowError,
        timeout: const Duration(seconds: 10),
      );
      // return _mapStatusReply(result);
      return CheckCastingStatusReply.fromJson(result);
    } catch (e) {
      log.info('Failed to get device status: $e');
      rethrow;
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
    DP1CallRequest request,
  ) async {
    final result = await sendDP1Call(request);
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
  Future<MoveToArtworkReply> moveToArtwork(MoveToArtworkRequest request) async {
    final result = await _sendData(_getBody(request));
    return MoveToArtworkReply.fromJson(result);
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
  Future<void> safeRestart(SafeRestartRequest request) async {
    try {
      await _sendData(_getBody(request));
    } catch (e) {
      log.warning('Failed to perform safe restart: $e');
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
  final FFBluetoothDevice _device;

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

  @override
  Future<Map<String, dynamic>> sendDP1Call(DP1CallRequest request) async {
    await BluetoothDeviceManager().switchDevice(_device);
    final res = await _sendData(
      RequestBody(request).toJson(),
      shouldShowError: false,
      timeout: const Duration(seconds: 10),
    );
    log.info('[TvCastServiceImpl] sendDP1Call response: $res');
    return res;
  }
}
