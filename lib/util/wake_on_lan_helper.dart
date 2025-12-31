import 'dart:io';

import 'package:autonomy_flutter/util/log.dart';
import 'package:wake_on_lan/wake_on_lan.dart';

class WakeOnLanHelper {
  /// Attempts to wake a device using Wake-on-LAN
  /// 
  /// [deviceHostname] - The hostname in format "FF1-XXXXXXXX.local"
  /// [macAddress] - The MAC address of the device in format "AA:BB:CC:DD:EE:FF"
  /// [port] - The port to send the magic packet on (default: 9)
  /// [repeat] - Number of times to repeat sending the packet (default: 5)
  /// 
  /// Returns true if the packet was sent successfully, false otherwise
  static Future<bool> wakeDevice({
    required String deviceHostname,
    required String macAddress,
    int port = 9,
    int repeat = 5,
  }) async {
    try {
      log
        ..info('[WakeOnLAN] Attempting to wake device: $deviceHostname')
        ..info('[WakeOnLAN] MAC Address: $macAddress');

      // Validate MAC address format
      final macValidation = MACAddress.validate(macAddress);
      if (!macValidation.state) {
        log.severe('[WakeOnLAN] Invalid MAC address: ${macValidation.error}');
        return false;
      }

      // Create MAC address instance
      final mac = MACAddress(macAddress);

      // Resolve hostname to IP address
      IPAddress? ipAddress;
      try {
        log.info('[WakeOnLAN] Resolving hostname: $deviceHostname');
        ipAddress = await IPAddress.fromHost(deviceHostname);
        log.info('[WakeOnLAN] Resolved to IP: ${ipAddress.address}');
      } catch (e) {
        log.warning(
          '[WakeOnLAN] Failed to resolve hostname, using broadcast address: $e',
        );
        // Fallback to broadcast address
        ipAddress = IPAddress('255.255.255.255');
      }

      // Create and send Wake-on-LAN packet
      final wol = WakeOnLAN(ipAddress, mac, port: port);
      
      await wol.wake(
        repeat: repeat,
        repeatDelay: const Duration(milliseconds: 500),
      );

      log.info('[WakeOnLAN] Magic packet sent successfully');
      return true;
    } on SocketException catch (e) {
      log.severe('[WakeOnLAN] Network error: $e');
      return false;
    } catch (e) {
      log.severe('[WakeOnLAN] Unexpected error: $e');
      return false;
    }
  }

  /// Validates a MAC address string
  /// Returns true if valid, false otherwise
  static bool isValidMacAddress(String macAddress) {
    final validation = MACAddress.validate(macAddress);
    return validation.state;
  }

  /// Formats a device ID into mDNS hostname format
  /// Example: "FF1-XXXXXXXX" -> "FF1-XXXXXXXX.local"
  static String formatHostname(String deviceId) {
    if (deviceId.endsWith('.local')) {
      return deviceId;
    }
    return '$deviceId.local';
  }
}
