//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/util/log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  NetworkService() {
    // Initialize current connectivity state
    _initializeConnectivity();

    addListener(
      (result) {
        log.info('[NetworkService] Network changed: $result');
        final hadInternet = hasInternet;
        _connectivityResult = result;

        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 5), () {
          isWifiNotifier.value = isWifi;
          hasInternetNotifier.value = hasInternet;

          // Log when internet connection is restored
          if (!hadInternet && hasInternet) {
            log.info('[NetworkService] Internet connection restored');
          }
        });
      },
      id: _defaultListenerId,
    );
  }

  static const String _defaultListenerId = 'defaultListenerId';
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _connectivityResult = [ConnectivityResult.none];
  final ValueNotifier<bool> isWifiNotifier = ValueNotifier(false);
  final ValueNotifier<bool> hasInternetNotifier = ValueNotifier(false);
  Timer? _timer;

  static const String canvasBlocListenerId = 'canvasBlocListenerId';
  static const String beaconListenerId = 'beaconListenerId';

  /// Initialize connectivity state on startup
  Future<void> _initializeConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _connectivityResult = result;
      hasInternetNotifier.value = hasInternet;
      log.info('[NetworkService] Initial connectivity: $result');
    } catch (e) {
      log.info('[NetworkService] Failed to check connectivity: $e');
    }
  }

  void addListener(
    void Function(List<ConnectivityResult> result) fn, {
    String? id,
  }) {
    _connectivity.onConnectivityChanged.listen(fn);
  }

  bool get isWifi => _connectivityResult.contains(ConnectivityResult.wifi);

  /// Check if device has internet connection (WiFi, mobile, ethernet, etc.)
  bool get hasInternet =>
      _connectivityResult.any(
        (result) =>
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn,
      ) &&
      !_connectivityResult.contains(ConnectivityResult.none);

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _connectivityResult = result;
      return hasInternet;
    } catch (e) {
      log.info('[NetworkService] Failed to check connectivity: $e');
      return false;
    }
  }
}
