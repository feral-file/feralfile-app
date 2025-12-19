import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';

abstract class NowDisplayingException implements Exception {
  const NowDisplayingException({required this.device});
  final FFBluetoothDevice device;
}

class NowDisplayingExceptionImpl implements NowDisplayingException {
  const NowDisplayingExceptionImpl({required this.device});
  final FFBluetoothDevice device;
}

class CheckCastingStatusException extends NowDisplayingExceptionImpl {
  const CheckCastingStatusException(
      {required super.device, required this.error});

  final ReplyError error;
}

class CannotGetNowDisplayingException extends NowDisplayingExceptionImpl {
  const CannotGetNowDisplayingException({required super.device, this.error});

  final Object? error;

  @override
  String toString() =>
      '${device.name} is connected but cannot get now playing';
}
