import 'package:autonomy_flutter/model/error/error.dart';
import 'package:collection/collection.dart';

enum FFBluetoothResponseErrorCode {
  userEnterWrongPassword(1),
  wifiConnectedButNoInternet(2),
  wifiConnectedButCannotReachServer(3),
  // BLE_ERR_CODE_WIFI_REQUIRED
  wifiRequired(4),
  // BLE_ERR_CODE_DEVICE_UPDATING
  deviceUpdating(5),
  // BLE_ERR_CODE_VERSION_CHECK_FAILED
  versionCheckFailed(6),
  unknownError(255);

  const FFBluetoothResponseErrorCode(this.code);

  final int code;
}

class FFBluetoothResponseError implements FFError {
  FFBluetoothResponseError(this.message, {this.title = 'Error'});

  @override
  final String message;
  final String title;

  /// Whether this error should trigger navigation back when caught.
  bool get shouldGoBack => false;

  /// Whether this error should show a "Contact support" button in the dialog.
  bool get shouldShowSupportButton => false;

  static FFBluetoothResponseError fromErrorCode(int errorCode) {
    final error = FFBluetoothResponseErrorCode.values
        .firstWhereOrNull((e) => e.code == errorCode);
    switch (error) {
      case FFBluetoothResponseErrorCode.userEnterWrongPassword:
        return WrongWifiPasswordError();
      case FFBluetoothResponseErrorCode.wifiConnectedButCannotReachServer:
        return WifiServerUnreachableError();
      case FFBluetoothResponseErrorCode.wifiConnectedButNoInternet:
        return WifiNoInternetError();
      case FFBluetoothResponseErrorCode.wifiRequired:
        return WifiRequiredError();
      case FFBluetoothResponseErrorCode.deviceUpdating:
        return DeviceUpdatingError();

      case FFBluetoothResponseErrorCode.versionCheckFailed:
        return DeviceVersionCheckFailedError();
      default:
        // Treat all other / unknown codes as unknown send‑WiFi errors.
        return UnknownSendWifiError(errorCode);
    }
  }

  // toString() {
  @override
  String toString() {
    return message;
  }
}

/// Base class for all errors related to the send‑WiFi‑credentials flow.
///
/// This makes it easier to distinguish Wi‑Fi setup issues from other
/// Bluetooth features while still preserving the existing
/// `FFBluetoothResponseError` contract.
abstract class SendWifiError extends FFBluetoothResponseError {
  SendWifiError(
    super.message, {
    super.title,
  });
}

class WrongWifiPasswordError extends SendWifiError {
  WrongWifiPasswordError()
      : super(
          'FF1 couldn\'t connect to Wi‑Fi. The password may be incorrect. Check it and try again.',
          title: 'Incorrect Wi‑Fi password',
        );
}

class WifiNoInternetError extends SendWifiError {
  WifiNoInternetError()
      : super(
          'FF1 is connected to Wi‑Fi but can\'t reach the internet. Check the router connection, then try again.',
          title: 'No internet access',
        );
}

class WifiServerUnreachableError extends SendWifiError {
  WifiServerUnreachableError()
      : super(
          'FF1 is online but can\'t reach the server. Network settings may be blocking access. Check firewall settings or try a different network.',
          title: 'Can\'t reach server',
        );
}

class WifiRequiredError extends SendWifiError {
  WifiRequiredError()
      : super(
          'FF1 needs a Wi‑Fi connection. Connect to a network to continue.',
          title: 'Wi‑Fi required',
        );
}

class UnknownSendWifiError extends SendWifiError {
  UnknownSendWifiError(int errorCode)
      : super(
          'FF1 couldn\'t connect to Wi‑Fi. The network conditions may be unstable. Move FF1 closer to the router and try again.',
          title: 'Wi‑Fi connection failed',
        );
}

class DeviceUpdatingError extends SendWifiError {
  DeviceUpdatingError()
      : super(
          'FF1 is installing an update. Wait for the update to finish, then try again.',
          title: 'FF1 is updating',
        );

  @override
  bool get shouldGoBack => true;
}

class DeviceVersionCheckFailedError extends SendWifiError {
  DeviceVersionCheckFailedError()
      : super(
          'FF1 couldn\'t complete setup. This may be related to a connection issue. Contact support for help.',
          title: 'Setup failed',
        );

  @override
  bool get shouldGoBack => true;

  @override
  bool get shouldShowSupportButton => true;
}
