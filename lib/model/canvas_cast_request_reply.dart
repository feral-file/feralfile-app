// Import statements for Flutter

// ignore_for_file: avoid_unused_constructor_parameters

import 'dart:math';

import 'package:autonomy_flutter/model/device/device_display_setting.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:flutter/material.dart';

enum CastCommand {
  checkStatus,
  displayPlaylist,
  pauseCasting,
  resumeCasting,
  nextArtwork,
  previousArtwork,
  moveToArtwork,
  updateDuration,
  connect,
  disconnect,
  sendKeyboardEvent,
  rotate,
  getDeviceStatus,
  updateArtFraming,
  updateToLatestVersion,
  tapGesture,
  dragGesture,
  showPairingQRCode,
  updateDisplaySettings,
  shutdown,
  reboot,
  deviceMetrics;

  static CastCommand fromString(String command) {
    switch (command) {
      case 'checkStatus':
        return CastCommand.checkStatus;
      case 'displayPlaylist':
        return CastCommand.displayPlaylist;
      case 'pauseCasting':
        return CastCommand.pauseCasting;
      case 'resumeCasting':
        return CastCommand.resumeCasting;
      case 'nextArtwork':
        return CastCommand.nextArtwork;
      case 'previousArtwork':
        return CastCommand.previousArtwork;
      case 'moveToArtwork':
        return CastCommand.moveToArtwork;
      case 'updateDuration':
        return CastCommand.updateDuration;
      case 'connect':
        return CastCommand.connect;
      case 'disconnect':
        return CastCommand.disconnect;
      case 'sendKeyboardEvent':
        return CastCommand.sendKeyboardEvent;
      case 'rotate':
        return CastCommand.rotate;
      case 'getDeviceStatus':
        return CastCommand.getDeviceStatus;
      case 'updateArtFraming':
        return CastCommand.updateArtFraming;
      case 'updateToLatestVersion':
        return CastCommand.updateToLatestVersion;
      case 'tapGesture':
        return CastCommand.tapGesture;
      case 'dragGesture':
        return CastCommand.dragGesture;
      case 'showPairingQRCode':
        return CastCommand.showPairingQRCode;
      case 'updateDisplaySettings':
        return CastCommand.updateDisplaySettings;
      case 'shutdown':
        return CastCommand.shutdown;
      case 'reboot':
        return CastCommand.reboot;
      case 'deviceMetrics':
        return CastCommand.deviceMetrics;
      default:
        throw ArgumentError('Unknown command: $command');
    }
  }

  static CastCommand fromRequest(FF1Request request) {
    switch (request.runtimeType) {
      case const (CheckCastingStatusRequest):
        return CastCommand.checkStatus;
      case const (CastDP1JsonPlaylistRequest):
      case const (CastDP1UrlPlaylistRequest):
      case const (CastDP1PlaylistRequestAbstract):
        return CastCommand.displayPlaylist;
      case const (PauseCastingRequest):
        return CastCommand.pauseCasting;
      case const (ResumeCastingRequest):
        return CastCommand.resumeCasting;
      case const (NextArtworkRequest):
        return CastCommand.nextArtwork;
      case const (PreviousArtworkRequest):
        return CastCommand.previousArtwork;
      case const (MoveToArtworkRequest):
        return CastCommand.moveToArtwork;
      case const (UpdateDurationRequest):
        return CastCommand.updateDuration;
      case const (ConnectRequestV2):
        return CastCommand.connect;
      case const (DisconnectRequestV2):
        return CastCommand.disconnect;
      case const (KeyboardEventRequest):
        return CastCommand.sendKeyboardEvent;
      case const (RotateRequest):
        return CastCommand.rotate;
      case const (GetDeviceStatusRequest):
        return CastCommand.getDeviceStatus;
      case const (UpdateArtFramingRequest):
        return CastCommand.updateArtFraming;
      case const (UpdateToLatestVersionRequest):
        return CastCommand.updateToLatestVersion;
      case const (TapGestureRequest):
        return CastCommand.tapGesture;
      case const (DragGestureRequest):
        return CastCommand.dragGesture;
      case const (ShowPairingQRCodeRequest):
        return CastCommand.showPairingQRCode;
      case const (UpdateDisplaySettingsRequest):
        return CastCommand.updateDisplaySettings;
      case const (SafeShutdownRequest):
        return CastCommand.shutdown;
      case const (SafeRestartRequest):
        return CastCommand.reboot;
      case const (DeviceRealtimeMetricsRequest):
        return CastCommand.deviceMetrics;
      default:
        throw Exception('Unknown request type');
    }
  }
}

class RequestBody {
  RequestBody(this.request) : command = CastCommand.fromRequest(request);
  final CastCommand command;
  final FF1Request request;

  Map<String, dynamic> toJson() => {
        'command': command.toString().split('.').last,
        'request': request.toJson(),
      };
}

enum ReplyError {
  overheating,
  unknown,
  ;

  static ReplyError fromString(String error) {
    switch (error) {
      case 'overheating':
        return ReplyError.overheating;
      default:
        return ReplyError.unknown;
    }
  }

  String get jsonString => switch (this) {
        ReplyError.overheating => 'overheating',
        ReplyError.unknown => 'unknown',
      };

  String get message => switch (this) {
        ReplyError.overheating => '''
Device temperature is too high. Playback paused to prevent damage.''',
        ReplyError.unknown => 'Unknown error',
      };
}

class Reply {
  Reply();

  factory Reply.fromJson(Map<String, dynamic> json) => Reply();

  Map<String, dynamic> toJson() => {};
}

class ReplyWithOK extends Reply {
  ReplyWithOK({required this.ok, this.error});

  factory ReplyWithOK.fromJson(Map<String, dynamic> json) => ReplyWithOK(
        ok: json['ok'] as bool,
        error: json['error'] != null
            ? ReplyError.fromString(json['error'] as String)
            : null,
      );
  final bool ok;
  final ReplyError? error;

  @override
  Map<String, dynamic> toJson() => {
        'ok': ok,
        'error': error?.jsonString,
      };
}

abstract class FF1Request {
  Map<String, dynamic> toJson();
}

// Enum for DevicePlatform
enum DevicePlatform {
  iOS,
  android,
  macos,
  tizenTV,
  androidTV,
  lgTV,
  other,
}

// Class representing DeviceInfoV2 message
class DeviceInfoV2 {
  DeviceInfoV2({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  factory DeviceInfoV2.fromJson(Map<String, dynamic> json) => DeviceInfoV2(
        deviceId: json['device_id'] as String,
        deviceName: json['device_name'] as String,
        platform: DevicePlatform.values[json['platform'] as int? ?? 0],
      );
  String deviceId;
  String deviceName;
  DevicePlatform? platform;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform?.index,
      };
}

// Class representing ConnectRequestV2 message
class ConnectRequestV2 implements FF1Request {
  ConnectRequestV2({required this.clientDevice, required this.primaryAddress});

  factory ConnectRequestV2.fromJson(Map<String, dynamic> json) =>
      ConnectRequestV2(
        clientDevice:
            DeviceInfoV2.fromJson(json['clientDevice'] as Map<String, dynamic>),
        primaryAddress: json['primaryAddress'] as String?,
      );
  DeviceInfoV2 clientDevice;

  // primaryAddress is used for mixpanel identity
  String? primaryAddress;

  @override
  Map<String, dynamic> toJson() => {
        'clientDevice': clientDevice.toJson(),
        'primaryAddress': primaryAddress,
      };
}

// Class representing ConnectReplyV2 message
class ConnectReplyV2 extends ReplyWithOK {
  ConnectReplyV2({required super.ok, this.canvasDevice});

  factory ConnectReplyV2.fromJson(Map<String, dynamic> json) => ConnectReplyV2(
        ok: json['ok'] as bool,
        canvasDevice: json['canvasDevice'] != null
            ? DeviceInfoV2.fromJson(
                json['canvasDevice'] as Map<String, dynamic>,
              )
            : null,
      );
  DeviceInfoV2? canvasDevice;

  @override
  Map<String, dynamic> toJson() => {
        'ok': ok,
        'canvasDevice': canvasDevice?.toJson(),
      };
}

// Class representing DisconnectRequestV2 message
class DisconnectRequestV2 implements FF1Request {
  DisconnectRequestV2();

  factory DisconnectRequestV2.fromJson(Map<String, dynamic> json) =>
      DisconnectRequestV2();

  @override
  Map<String, dynamic> toJson() => {};
}

// Class representing DisconnectReplyV2 message
class DisconnectReplyV2 extends ReplyWithOK {
  DisconnectReplyV2({required super.ok});

  factory DisconnectReplyV2.fromJson(Map<String, dynamic> json) =>
      DisconnectReplyV2(ok: json['ok'] as bool);
}

// Class representing CastAssetToken message
class CastAssetToken implements FF1Request {
  CastAssetToken({required this.id});

  factory CastAssetToken.fromJson(Map<String, dynamic> json) => CastAssetToken(
        id: json['id'] as String,
      );
  String id;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
      };
}

// Class representing CastArtwork message
class CastArtwork implements FF1Request {
  CastArtwork({required this.url, required this.mimetype});

  factory CastArtwork.fromJson(Map<String, dynamic> json) => CastArtwork(
        url: json['url'] as String,
        mimetype: json['mimetype'] as String,
      );
  String url;
  String mimetype;

  @override
  Map<String, dynamic> toJson() => {
        'url': url,
        'mimetype': mimetype,
      };
}

// Class representing PlayArtworkV2 message
class PlayArtworkV2 {
  PlayArtworkV2({
    required this.duration,
    this.token,
    this.artwork,
  });

  factory PlayArtworkV2.fromJson(Map<String, dynamic> json) => PlayArtworkV2(
        token: json['token'] != null
            ? CastAssetToken.fromJson(json['token'] as Map<String, dynamic>)
            : null,
        artwork: json['artwork'] != null
            ? CastArtwork.fromJson(json['artwork'] as Map<String, dynamic>)
            : null,
        duration: Duration(milliseconds: json['duration'] as int),
      );
  CastAssetToken? token;
  CastArtwork? artwork;
  Duration duration;

  Map<String, dynamic> toJson() => {
        if (token != null) 'token': token?.toJson(),
        if (artwork != null) 'artwork': artwork!.toJson(),
        'duration': duration.inMilliseconds,
      };
}

// Class representing CheckDeviceStatusRequest message
class CheckCastingStatusRequest implements FF1Request {
  CheckCastingStatusRequest();

  factory CheckCastingStatusRequest.fromJson(Map<String, dynamic> json) =>
      CheckCastingStatusRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

// Class representing CheckDeviceStatusReply message
class CheckCastingStatusReply extends ReplyWithOK {
  CheckCastingStatusReply({
    required super.ok,
    this.index,
    bool? isPaused,
    this.connectedDevice,
    this.displayKey,
    this.deviceSettings,
    super.error,
    this.items,
  }) : isPaused = isPaused ?? false;

  factory CheckCastingStatusReply.fromJson(Map<String, dynamic> json) =>
      CheckCastingStatusReply(
        ok: json['ok'] as bool,
        index: json['index'] as int?,
        isPaused: json['isPaused'] as bool?,
        connectedDevice: json['connectedDevice'] != null
            ? DeviceInfoV2.fromJson(
                json['connectedDevice'] as Map<String, dynamic>,
              )
            : null,
        displayKey: json['displayKey'] as String?,
        deviceSettings: json['deviceSettings'] != null
            ? DeviceDisplaySetting.fromJson(
                json['deviceSettings'] as Map<String, dynamic>,
              )
            : null,
        items: json['items'] == null
            ? null
            : List<DP1Item>.from(
                (json['items'] as List).map(
                  (x) => DP1Item.fromJson(
                    Map<String, dynamic>.from(x as Map),
                  ),
                ),
              ),
        error: json['error'] != null
            ? ReplyError.fromString(json['error'] as String)
            : null,
      );

  int? get currentArtworkIndex {
    return index;
  }

  int? index;
  bool isPaused;
  DeviceInfoV2? connectedDevice;
  String? displayKey;
  DeviceDisplaySetting? deviceSettings;
  final List<DP1Item>? items;

  @override
  Map<String, dynamic> toJson() => {
        'ok': super.ok,
        'index': index,
        'isPaused': isPaused,
        'connectedDevice': connectedDevice?.toJson(),
        'displayKey': displayKey,
        'deviceSettings': deviceSettings?.toJson(),
        'error': super.error?.jsonString,
      };

  // copyWith method
  CheckCastingStatusReply copyWith({
    bool? ok,
    int? index,
    bool? isPaused,
    DeviceInfoV2? connectedDevice,
    String? exhibitionId,
    String? catalogId,
    String? displayKey,
    DeviceDisplaySetting? deviceSettings,
    List<DP1Item>? items,
    ReplyError? error,
  }) {
    return CheckCastingStatusReply(
      ok: super.ok,
      index: index ?? this.index,
      isPaused: isPaused ?? this.isPaused,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      displayKey: displayKey ?? this.displayKey,
      deviceSettings: deviceSettings ?? this.deviceSettings,
      items: items ?? this.items,
      error: error ?? super.error,
    );
  }
}

abstract class CastDP1PlaylistRequestAbstract extends FF1Request {
  CastDP1PlaylistRequestAbstract({required this.intent});

  final DP1Intent intent;
}

class CastDP1JsonPlaylistRequest implements CastDP1PlaylistRequestAbstract {
  CastDP1JsonPlaylistRequest({
    required this.dp1Call,
    required this.intent,
  });

  factory CastDP1JsonPlaylistRequest.fromJson(Map<String, dynamic> json) {
    return CastDP1JsonPlaylistRequest(
      dp1Call: DP1Call.fromJson(json['dp1_call'] as Map<String, dynamic>),
      intent: DP1Intent.fromJson(json['intent'] as Map<String, dynamic>),
    );
  }

  final DP1Call dp1Call;
  @override
  final DP1Intent intent;

  @override
  Map<String, dynamic> toJson() {
    return {
      'dp1_call': dp1Call.toJson(),
      'intent': intent.toJson(),
    };
  }
}

class CastDP1UrlPlaylistRequest implements CastDP1PlaylistRequestAbstract {
  factory CastDP1UrlPlaylistRequest.fromDp1Playlist(
      DP1Call dp1Call, DP1Intent intent) {
    return CastDP1UrlPlaylistRequest(
      playlistUrl: dp1Call.url,
      intent: intent,
    );
  }
  CastDP1UrlPlaylistRequest({required this.playlistUrl, required this.intent});
  final String playlistUrl; // url of the playlist
  @override
  final DP1Intent intent;

  @override
  Map<String, dynamic> toJson() => {
        'playlistUrl': playlistUrl,
        'intent': intent.toJson(),
      };
}

// Class representing CastListArtworkReply message
class CastDP1PlaylistReply extends ReplyWithOK {
  CastDP1PlaylistReply({required super.ok});

  factory CastDP1PlaylistReply.fromJson(Map<String, dynamic> json) =>
      CastDP1PlaylistReply(ok: json['ok'] as bool);

  @override
  Map<String, dynamic> toJson() => {
        'ok': ok,
      };
}

// Class representing PauseCastingRequest message
class PauseCastingRequest implements FF1Request {
  PauseCastingRequest();

  factory PauseCastingRequest.fromJson(Map<String, dynamic> json) =>
      PauseCastingRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

// Class representing PauseCastingReply message
class PauseCastingReply extends ReplyWithOK {
  PauseCastingReply({required super.ok});

  factory PauseCastingReply.fromJson(Map<String, dynamic> json) =>
      PauseCastingReply(ok: json['ok'] as bool);
}

// Class representing ResumeCastingRequest message
class ResumeCastingRequest implements FF1Request {
  ResumeCastingRequest({this.startTime});

  factory ResumeCastingRequest.fromJson(Map<String, dynamic> json) =>
      ResumeCastingRequest(
        startTime: int.tryParse(json['startTime'] as String),
      );
  int? startTime;

  @override
  Map<String, dynamic> toJson() => {
        'startTime': startTime,
      };
}

// Class representing ResumeCastingReply message
class ResumeCastingReply extends ReplyWithOK {
  ResumeCastingReply({required super.ok});

  factory ResumeCastingReply.fromJson(Map<String, dynamic> json) =>
      ResumeCastingReply(ok: json['ok'] as bool);
}

// Class representing NextArtworkRequest message
class NextArtworkRequest implements FF1Request {
  NextArtworkRequest({this.startTime});

  factory NextArtworkRequest.fromJson(Map<String, dynamic> json) =>
      NextArtworkRequest(
        startTime: int.tryParse(json['startTime'] as String),
      );
  int? startTime;

  @override
  Map<String, dynamic> toJson() => {
        'startTime': startTime,
      };
}

// Class representing NextArtworkReply message
class NextArtworkReply extends ReplyWithOK {
  NextArtworkReply({required super.ok});

  factory NextArtworkReply.fromJson(Map<String, dynamic> json) =>
      NextArtworkReply(ok: json['ok'] as bool);
}

// Class representing PreviousArtworkRequest message
class PreviousArtworkRequest implements FF1Request {
  PreviousArtworkRequest({this.startTime});

  factory PreviousArtworkRequest.fromJson(Map<String, dynamic> json) =>
      PreviousArtworkRequest(
        startTime: int.tryParse(json['startTime'] as String),
      );
  int? startTime;

  @override
  Map<String, dynamic> toJson() => {
        'startTime': startTime,
      };
}

// Class representing PreviousArtworkReply message
class PreviousArtworkReply extends ReplyWithOK {
  PreviousArtworkReply({required super.ok});

  factory PreviousArtworkReply.fromJson(Map<String, dynamic> json) =>
      PreviousArtworkReply(ok: json['ok'] as bool);
}

class MoveToArtworkRequest implements FF1Request {
  MoveToArtworkRequest({required this.index});
  int index;

  @override
  Map<String, dynamic> toJson() => {'index': index};
}

class MoveToArtworkReply extends ReplyWithOK {
  MoveToArtworkReply({required super.ok});

  factory MoveToArtworkReply.fromJson(Map<String, dynamic> json) =>
      MoveToArtworkReply(ok: json['ok'] as bool);
}

// Class representing UpdateDurationRequest message
class UpdateDurationRequest implements FF1Request {
  UpdateDurationRequest({required this.artworks});

  factory UpdateDurationRequest.fromJson(Map<String, dynamic> json) =>
      UpdateDurationRequest(
        artworks: List<PlayArtworkV2>.from(
          (json['artworks'] as List).map(
            (x) => PlayArtworkV2.fromJson(Map<String, dynamic>.from(x as Map)),
          ),
        ),
      );

  List<PlayArtworkV2> artworks;

  @override
  Map<String, dynamic> toJson() => {
        'artworks': artworks.map((artwork) => artwork.toJson()).toList(),
      };
}

// Class representing UpdateDurationReply message
class UpdateDurationReply extends Reply {
  UpdateDurationReply({
    required this.artworks,
  });

  factory UpdateDurationReply.fromJson(Map<String, dynamic> json) =>
      UpdateDurationReply(
        artworks: List<PlayArtworkV2>.from(
          (json['artworks'] as List).map(
            (x) => PlayArtworkV2.fromJson(
              Map<String, dynamic>.from(x as Map),
            ),
          ),
        ),
      );
  List<PlayArtworkV2> artworks;

  @override
  Map<String, dynamic> toJson() => {
        'artworks': artworks.map((artwork) => artwork.toJson()).toList(),
      };
}

class KeyboardEventRequest implements FF1Request {
  KeyboardEventRequest({required this.code});

  @override
  factory KeyboardEventRequest.fromJson(Map<String, dynamic> json) =>
      KeyboardEventRequest(code: json['code'] as int);
  final int code;

  @override
  Map<String, dynamic> toJson() => {'code': code};
}

class KeyboardEventReply extends ReplyWithOK {
  KeyboardEventReply({required super.ok});

  factory KeyboardEventReply.fromJson(Map<String, dynamic> json) =>
      KeyboardEventReply(ok: json['ok'] as bool);
}

class RotateRequest implements FF1Request {
  RotateRequest({required this.clockwise});

  factory RotateRequest.fromJson(Map<String, dynamic> json) =>
      RotateRequest(clockwise: json['clockwise'] as bool);
  final bool clockwise;

  @override
  Map<String, dynamic> toJson() => {'clockwise': clockwise};
}

class RotateReply extends Reply {
  RotateReply({required this.orientation});

  factory RotateReply.fromJson(Map<String, dynamic> json) => RotateReply(
        orientation: json['orientation'] != null
            ? ScreenOrientation.fromString(json['orientation'] as String)
            : null,
      );
  final ScreenOrientation? orientation;

  @override
  Map<String, dynamic> toJson() => {'orientation': orientation};
}

extension OrientationExtension on Orientation {
  String get name {
    switch (this) {
      case Orientation.portrait:
        return 'portrait';
      case Orientation.landscape:
        return 'landscape';
    }
  }

  static Orientation fromString(String orientation) {
    switch (orientation) {
      case 'portrait':
        return Orientation.portrait;
      case 'landscape':
        return Orientation.landscape;
      default:
        throw ArgumentError('Unknown orientation: $orientation');
    }
  }
}

class GetDeviceStatusRequest implements FF1Request {
  GetDeviceStatusRequest();

  factory GetDeviceStatusRequest.fromJson(Map<String, dynamic> json) =>
      GetDeviceStatusRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

class GetDeviceStatusReply extends Reply {
  GetDeviceStatusReply({required this.deviceStatus});

  factory GetDeviceStatusReply.fromJson(Map<String, dynamic> json) =>
      GetDeviceStatusReply(
        deviceStatus: DeviceStatus.fromJson(
          json,
        ),
      );
  final DeviceStatus deviceStatus;

  @override
  Map<String, dynamic> toJson() => deviceStatus.toJson();
}

class UpdateToLatestVersionRequest implements FF1Request {
  UpdateToLatestVersionRequest();

  factory UpdateToLatestVersionRequest.fromJson(Map<String, dynamic> json) =>
      UpdateToLatestVersionRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

class UpdateToLatestVersionReply extends Reply {
  UpdateToLatestVersionReply();

  factory UpdateToLatestVersionReply.fromJson(Map<String, dynamic> json) =>
      UpdateToLatestVersionReply();
}

enum ArtFraming {
  fitToScreen,
  cropToFill;

  int get value {
    switch (this) {
      case ArtFraming.fitToScreen:
        return 0;
      case ArtFraming.cropToFill:
        return 1;
    }
  }

  String get name {
    switch (this) {
      case ArtFraming.fitToScreen:
        return 'fit';
      case ArtFraming.cropToFill:
        return 'fill';
    }
  }

  static ArtFraming fromString(String framing) {
    switch (framing) {
      case 'fit':
        return ArtFraming.fitToScreen;
      case 'fill':
        return ArtFraming.cropToFill;
      default:
        throw ArgumentError('Unknown framing: $framing');
    }
  }

  static ArtFraming fromValue(int value) {
    switch (value) {
      case 0:
        return ArtFraming.fitToScreen;
      case 1:
        return ArtFraming.cropToFill;
      default:
        throw ArgumentError('Unknown value: $value');
    }
  }
}

class UpdateArtFramingRequest implements FF1Request {
  UpdateArtFramingRequest({required this.artFraming});

  factory UpdateArtFramingRequest.fromJson(Map<String, dynamic> json) =>
      UpdateArtFramingRequest(
        artFraming: ArtFraming.fromValue(json['frameConfig'] as int),
      );
  final ArtFraming artFraming;

  @override
  Map<String, dynamic> toJson() => {
        'frameConfig': artFraming.value,
      };
}

class UpdateArtFramingReply extends ReplyWithOK {
  UpdateArtFramingReply({required super.ok});

  factory UpdateArtFramingReply.fromJson(Map<String, dynamic> json) =>
      UpdateArtFramingReply(ok: json['ok'] as bool);
}

class TapGestureRequest implements FF1Request {
  TapGestureRequest();

  @override
  factory TapGestureRequest.fromJson(Map<String, dynamic> json) =>
      TapGestureRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

class GestureReply extends ReplyWithOK {
  GestureReply({required super.ok});

  factory GestureReply.fromJson(Map<String, dynamic> json) =>
      GestureReply(ok: json['ok'] as bool);
}

class DragGestureRequest implements FF1Request {
  DragGestureRequest({required this.cursorOffsets});

  @override
  factory DragGestureRequest.fromJson(Map<String, dynamic> json) =>
      DragGestureRequest(
        cursorOffsets: List<CursorOffset>.from(
          (json['cursorOffsets'] as List)
              .map((x) => CursorOffset.fromJson(x as Map<String, dynamic>)),
        ),
      );
  List<CursorOffset> cursorOffsets;

  @override
  Map<String, dynamic> toJson() => {
        'cursorOffsets':
            cursorOffsets.map((cursorOffset) => cursorOffset.toJson()).toList(),
      };
}

class CursorOffset {
  CursorOffset({
    required this.dx,
    required this.dy,
  });

  factory CursorOffset.fromJson(Map<String, dynamic> json) => CursorOffset(
        dx: json['dx'] as double,
        dy: json['dy'] as double,
      );
  final double dx;
  final double dy;

  Map<String, dynamic> toJson() => {
        'dx': // round to 2 decimal places
            double.parse(dx.toStringAsFixed(2)),
        'dy': // round to 2 decimal places
            double.parse(dy.toStringAsFixed(2)),
      };
}

class EmptyRequest implements FF1Request {
  EmptyRequest();

  factory EmptyRequest.fromJson(Map<String, dynamic> json) => EmptyRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

class EmptyReply extends Reply {
  EmptyReply();

  factory EmptyReply.fromJson(Map<String, dynamic> json) => EmptyReply();

  @override
  Map<String, dynamic> toJson() => {};
}

// Class representing EnableMetricsStreamingRequest message
class EnableMetricsStreamingRequest implements FF1Request {
  EnableMetricsStreamingRequest();

  factory EnableMetricsStreamingRequest.fromJson(Map<String, dynamic> json) =>
      EnableMetricsStreamingRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

// Class representing EnableMetricsStreamingReply message
class EnableMetricsStreamingReply extends ReplyWithOK {
  EnableMetricsStreamingReply({required super.ok});

  factory EnableMetricsStreamingReply.fromJson(Map<String, dynamic> json) =>
      EnableMetricsStreamingReply(ok: json['ok'] as bool);
}

// Class representing DisableMetricsStreamingRequest message
class DisableMetricsStreamingRequest implements FF1Request {
  DisableMetricsStreamingRequest();

  factory DisableMetricsStreamingRequest.fromJson(Map<String, dynamic> json) =>
      DisableMetricsStreamingRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

// Class representing DisableMetricsStreamingReply message
class DisableMetricsStreamingReply extends ReplyWithOK {
  DisableMetricsStreamingReply({required super.ok});

  factory DisableMetricsStreamingReply.fromJson(Map<String, dynamic> json) =>
      DisableMetricsStreamingReply(ok: json['ok'] as bool);
}

// Class representing ShowPairingQRCodeRequest message
class ShowPairingQRCodeRequest implements FF1Request {
  ShowPairingQRCodeRequest({required this.show});

  factory ShowPairingQRCodeRequest.fromJson(Map<String, dynamic> json) =>
      ShowPairingQRCodeRequest(
        show: json['show'] as bool,
      );
  final bool show;

  @override
  Map<String, dynamic> toJson() => {
        'show': show,
      };
}

// Class representing ShowPairingQRCodeReply message
class ShowPairingQRCodeReply extends Reply {
  ShowPairingQRCodeReply({required this.success, this.error});

  factory ShowPairingQRCodeReply.fromJson(Map<String, dynamic> json) =>
      ShowPairingQRCodeReply(
        success: json['success'] as bool,
        error: json['error'] as String?,
      );
  final bool success;
  final String? error;

  @override
  Map<String, dynamic> toJson() => {
        'success': success,
        'error': error,
      };
}

class UpdateDisplaySettingsRequest implements FF1Request {
  UpdateDisplaySettingsRequest({
    required this.tokenId,
    required this.setting,
    this.isSaved = true,
  });

  final String tokenId;
  final ArtistDisplaySetting setting;
  final bool isSaved;

  @override
  Map<String, dynamic> toJson() => {
        'isSaved': isSaved,
        ...setting.toJson(),
        'tokenId': tokenId,
      };
}

class UpdateDisplaySettingsReply extends ReplyWithOK {
  UpdateDisplaySettingsReply({required super.ok});

  factory UpdateDisplaySettingsReply.fromJson(Map<String, dynamic> json) =>
      UpdateDisplaySettingsReply(ok: json['ok'] as bool);
}

class SafeShutdownRequest implements FF1Request {
  SafeShutdownRequest();

  factory SafeShutdownRequest.fromJson(Map<String, dynamic> json) =>
      SafeShutdownRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

class SafeRestartRequest implements FF1Request {
  SafeRestartRequest();

  factory SafeRestartRequest.fromJson(Map<String, dynamic> json) =>
      SafeRestartRequest();

  @override
  Map<String, dynamic> toJson() => {};
}

class DeviceRealtimeMetrics {
  DeviceRealtimeMetrics({
    this.cpu,
    this.gpu,
    this.memory,
    this.screen,
    this.uptime,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory DeviceRealtimeMetrics.fromJson(Map<String, dynamic> json) =>
      DeviceRealtimeMetrics(
        cpu: json['cpu'] != null
            ? DeviceCpu.fromJson(json['cpu'] as Map<String, dynamic>)
            : null,
        gpu: json['gpu'] != null
            ? DeviceGpu.fromJson(json['gpu'] as Map<String, dynamic>)
            : null,
        memory: json['memory'] != null
            ? DeviceMemory.fromJson(json['memory'] as Map<String, dynamic>)
            : null,
        screen: json['screen'] != null
            ? DeviceScreen.fromJson(json['screen'] as Map<String, dynamic>)
            : null,
        uptime: json['uptime'] != null
            ? double.parse(json['uptime'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'cpu': cpu?.toJson(),
        'gpu': gpu?.toJson(),
        'memory': memory?.toJson(),
        'screen': screen?.toJson(),
        'uptime': uptime,
      };

  final DeviceCpu? cpu;
  final DeviceGpu? gpu;
  final DeviceMemory? memory;
  final DeviceScreen? screen;
  final double? uptime;
  final int timestamp;
}

class DeviceCpu {
  DeviceCpu({
    this.maxFrequency,
    this.currentFrequency,
    this.maxTemperature,
    this.currentTemperature,
  });

  factory DeviceCpu.fromJson(Map<String, dynamic> json) => DeviceCpu(
        maxFrequency: json['max_frequency'] == null
            ? null
            : double.parse(json['max_frequency'].toString()),
        currentFrequency: json['current_frequency'] == null
            ? null
            : double.parse(json['current_frequency'].toString()),
        maxTemperature: json['max_temperature'] == null
            ? null
            : double.parse(json['max_temperature'].toString()),
        currentTemperature: json['current_temperature'] == null
            ? null
            : double.parse(json['current_temperature'].toString()),
      );
  final double? maxFrequency;
  final double? currentFrequency;
  final double? maxTemperature;
  final double? currentTemperature;

  Map<String, dynamic> toJson() => {
        'max_frequency': maxFrequency,
        'current_frequency': currentFrequency,
        'max_temperature': maxTemperature,
        'current_temperature': currentTemperature,
      };

  double? get cpuUsage {
    if (currentFrequency != null && maxFrequency != null) {
      return min(((currentFrequency! / maxFrequency!) * 100), 100);
    }
    return null;
  }
}

class DeviceGpu {
  DeviceGpu({
    this.maxFrequency,
    this.currentFrequency,
    this.maxTemperature,
    this.currentTemperature,
  });

  factory DeviceGpu.fromJson(Map<String, dynamic> json) => DeviceGpu(
        maxFrequency: json['max_frequency'] == null
            ? null
            : double.parse(json['max_frequency'].toString()),
        currentFrequency: json['current_frequency'] == null
            ? null
            : double.parse(json['current_frequency'].toString()),
        maxTemperature: json['max_temperature'] == null
            ? null
            : double.parse(json['max_temperature'].toString()),
        currentTemperature: json['current_temperature'] == null
            ? null
            : double.parse(json['current_temperature'].toString()),
      );
  final double? maxFrequency;
  final double? currentFrequency;
  final double? maxTemperature;
  final double? currentTemperature;

  Map<String, dynamic> toJson() => {
        'max_frequency': maxFrequency,
        'current_frequency': currentFrequency,
        'max_temperature': maxTemperature,
        'current_temperature': currentTemperature,
      };

  double? get gpuUsage {
    if (currentFrequency != null && maxFrequency != null) {
      return min(((currentFrequency! / maxFrequency!) * 100), 100);
    }
    return null;
  }
}

class DeviceMemory {
  DeviceMemory({
    this.maxCapacity,
    this.usedCapacity,
  });

  factory DeviceMemory.fromJson(Map<String, dynamic> json) => DeviceMemory(
        maxCapacity: json['max_capacity'] == null
            ? null
            : double.parse(json['max_capacity'].toString()),
        usedCapacity: json['used_capacity'] == null
            ? null
            : double.parse(json['used_capacity'].toString()),
      );
  final double? maxCapacity;
  final double? usedCapacity;

  Map<String, dynamic> toJson() => {
        'max_capacity': maxCapacity,
        'used_capacity': usedCapacity,
      };

  double? get memoryUsage {
    if (maxCapacity != null && usedCapacity != null) {
      return ((usedCapacity! / maxCapacity!) * 100);
    }
    return null;
  }
}

class DeviceScreen {
  DeviceScreen({
    this.width,
    this.height,
    this.refreshRate,
    this.fps,
  });

  factory DeviceScreen.fromJson(Map<String, dynamic> json) => DeviceScreen(
        width: json['width'] as int?,
        height: json['height'] as int?,
        refreshRate: json['refresh_rate'] == null
            ? null
            : double.parse(json['refresh_rate'].toString()),
        fps: json['fps'] == null ? null : double.parse(json['fps'].toString()),
      );
  final int? width;
  final int? height;
  final double? refreshRate;
  final double? fps;

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'refresh_rate': refreshRate,
        'fps': fps,
      };
}

// extension for DeviceScreen
extension DeviceScreenExtension on DeviceScreen {
  Size? get size {
    if (width != null && height != null && width! > 0 && height! > 0) {
      return Size(width!.toDouble(), height!.toDouble());
    }
    return null;
  }

  // size on Orientation
  Size? sizeOnOrientation(ScreenOrientation orientation) {
    if (size == null) return null;
    switch (orientation) {
      case ScreenOrientation.portrait:
      case ScreenOrientation.portraitReverse:
        return Size(size!.height, size!.width);
      case ScreenOrientation.landscape:
      case ScreenOrientation.landscapeReverse:
        return Size(size!.width, size!.height);
    }
  }
}

class DeviceRealtimeMetricsRequest implements FF1Request {
  DeviceRealtimeMetricsRequest();

  @override
  Map<String, dynamic> toJson() {
    return {};
  }
}

class DeviceRealtimeMetricsReply extends Reply {
  DeviceRealtimeMetricsReply({required this.metrics});

  factory DeviceRealtimeMetricsReply.fromJson(Map<String, dynamic> json) =>
      DeviceRealtimeMetricsReply(
        metrics: DeviceRealtimeMetrics.fromJson(
          json,
        ),
      );
  final DeviceRealtimeMetrics metrics;

  @override
  Map<String, dynamic> toJson() => metrics.toJson();
}
