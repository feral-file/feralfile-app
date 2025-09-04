//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/pubdoc_api.dart';
import 'package:autonomy_flutter/model/version_info.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/helpers.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum VersionCompatibilityResult {
  compatible, // 0: Thiết bị tương thích
  needUpdateApp, // 1: Cần update app
  needUpdateDevice, // 2: Cần update device
  unknown, // 3: Không xác định được
  deviceNotFound; // 4: Không có thiết bị

  bool get isValid =>
      this != VersionCompatibilityResult.needUpdateApp &&
      this != VersionCompatibilityResult.needUpdateDevice;
}

abstract class VersionService {
  Future<void> checkForUpdate();

  Future<void> showReleaseNotes({String? currentVersion});

  Future<void> openLatestVersion();

  /// Check version compatibility with FFBluetoothDevice
  /// Returns VersionCompatibilityResult to indicate if app needs update or downgrade
  Future<VersionCompatibilityResult> checkDeviceVersionCompatibility({
    String? dBranch,
    String? dVersion,
    bool requiredDeviceUpdate = true,
  });

  Future<PackageInfo> getPackageInfo();
}

class VersionServiceImpl implements VersionService {
  VersionServiceImpl(
    this._pubdocAPI,
    this._configurationService,
    this._navigationService,
  );

  final PubdocAPI _pubdocAPI;
  final ConfigurationService _configurationService;
  final NavigationService _navigationService;

  PackageInfo? _packageInfo;

  @override
  Future<PackageInfo> getPackageInfo() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  @override
  Future<VersionCompatibilityResult> checkDeviceVersionCompatibility({
    String? dBranch,
    String? dVersion,
    bool requiredDeviceUpdate = true,
  }) async {
    final device = BluetoothDeviceManager().castingBluetoothDevice;

    final deviceVersion = dVersion ??
        BluetoothDeviceManager().castingDeviceStatus.value?.installedVersion;
    final branchName = dBranch ?? device?.branchName;

    if (deviceVersion == null || branchName == null) {
      log.info('Device branch or version is null');
      return VersionCompatibilityResult.unknown;
    }

    final compatibility =
        await _checkDeviceVersionCompatibility(branchName, deviceVersion);
    switch (compatibility) {
      case VersionCompatibilityResult.needUpdateApp:
        await injector<NavigationService>().showVersionNotCompatibleDialog();
      case VersionCompatibilityResult.needUpdateDevice:
        log.info('Device needs update');
        if (requiredDeviceUpdate) {
          await injector<NavigationService>().showDeviceNotCompatibleDialog();
        }
      default:
    }
    return compatibility;
  }

  /// Find the latest version in branchData that is older than deviceVersion
  String? _findLatestCompatibleVersion(
      Map<String, dynamic> branchData, String deviceVersion) {
    String? latestVersion;

    for (final version in branchData.keys) {
      // Skip if version is not older than deviceVersion
      if (compareVersion(version, deviceVersion) >= 0) {
        continue;
      }

      // If this is the first valid version or it's newer than current latest
      if (latestVersion == null || compareVersion(version, latestVersion) > 0) {
        latestVersion = version;
      }
    }

    return latestVersion;
  }

  Future<VersionCompatibilityResult> _checkDeviceVersionCompatibility(
    String branchName,
    String deviceVersion,
  ) async {
    try {
      // Get version compatibility data from JSON file
      final versionCompatibilityData =
          await _pubdocAPI.getVersionsCompatibility();
      // await _getVersionCompatibilityData();

      // Get current app version and build number
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final fullAppVersion = '$appVersion($buildNumber)';

      log.info('Checking app version compatibility:');
      log.info('Branch: ${branchName}');
      log.info('Device version: $deviceVersion');
      log.info('App version: $fullAppVersion');

      // Get branch data
      final branchData = versionCompatibilityData[branchName];
      if (branchData == null) {
        log.info('No compatibility data found for branch: ${branchName}');
        return VersionCompatibilityResult.unknown;
      }

      // Find version info by device version
      var versionInfo = branchData[deviceVersion];
      if (versionInfo == null) {
        log.info(
          'No compatibility data found for device version: $deviceVersion, trying to find latest compatible version',
        );
        // Find the latest version that is older than deviceVersion
        final latestCompatibleVersion = _findLatestCompatibleVersion(
            branchData as Map<String, dynamic>, deviceVersion);
        if (latestCompatibleVersion == null) {
          log.info(
              'No compatible version found for device version: $deviceVersion');
          return VersionCompatibilityResult.unknown;
        }
        versionInfo = branchData[latestCompatibleVersion];
        log.info(
            'Using compatibility data from version: $latestCompatibleVersion');
      } else {
        log.info('Found compatibility data for device version: $deviceVersion');
      }

      // Determine platform and get min/max versions
      String? minVersion;
      String? maxVersion;

      if (Platform.isAndroid) {
        minVersion = versionInfo['min_android_version'] as String?;
        maxVersion = versionInfo['max_android_version'] as String?;
      } else if (Platform.isIOS) {
        minVersion = versionInfo['min_ios_version'] as String?;
        maxVersion = versionInfo['max_ios_version'] as String?;
      }

      // Check compatibility based on available version constraints
      if (minVersion != null &&
          compareVersion(fullAppVersion, minVersion) < 0) {
        return VersionCompatibilityResult.needUpdateApp;
      }

      if (maxVersion != null &&
          compareVersion(fullAppVersion, maxVersion) > 0) {
        return VersionCompatibilityResult.needUpdateDevice;
      }

      return VersionCompatibilityResult.compatible;
    } catch (e) {
      log.info('Error checking app version compatibility: $e');
      return VersionCompatibilityResult.unknown;
    }
  }

  @override
  Future checkForUpdate() async {
    if (kDebugMode) {
      return;
    }
    if (UIHelper.currentDialogTitle == 'update_required'.tr()) {
      return;
    }

    final versionInfo = await getVersionInfo();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    if (compareVersion(versionInfo.requiredVersion, currentVersion) > 0) {
      await showForceUpdateDialog(versionInfo.link);
    } else {
      // check to show Release Notes
      await showReleaseNotes(currentVersion: currentVersion);
    }
  }

  @override
  Future showReleaseNotes({String? currentVersion}) async {
    if (currentVersion != null) {
      final readVersion = _configurationService.getReadReleaseNotesVersion();
      if (readVersion == null ||
          compareVersion(readVersion, currentVersion) >= 0) {
        unawaited(
          _configurationService.setReadReleaseNotesInVersion(currentVersion),
        );
        return;
      }
    }

    final releaseNotes = await getReleaseNotes(currentVersion);
    if (releaseNotes == 'TBD') {
      return;
    }

    if (currentVersion != null) {
      await _configurationService.setReadReleaseNotesInVersion(currentVersion);
    }
    await showReleaseNodeDialog(releaseNotes);
  }

  Future<VersionInfo> getVersionInfo() async {
    final versionsInfo = await _pubdocAPI.getVersionsInfo();
    final isAppCenter = await isAppCenterBuild();
    var app = '';
    app += isAppCenter ? 'dev' : 'prod';
    app += Platform.isIOS ? '_ios' : '_android';

    switch (app) {
      case 'prod_ios':
        return versionsInfo.productionIOS;
      case 'prod_android':
      default:
        return versionsInfo.productionAndroid;
    }
  }

  Future<String> getReleaseNotes(String? currentVersion) async {
    var releaseNotes = '';
    try {
      final app = (await isAppCenterBuild()) ? 'dev' : 'production';
      releaseNotes = await _pubdocAPI.getReleaseNotesContent(app);

      if (currentVersion != null) {
        final textBegin = '[#] $currentVersion';
        if (!releaseNotes.startsWith(textBegin)) {
          releaseNotes = 'TBD';
        }
      }
    } catch (_) {
      releaseNotes = 'TBD';
    }

    return releaseNotes;
  }

  Future showForceUpdateDialog(String link) async {
    final context = _navigationService.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final theme = Theme.of(context);
    await UIHelper.showDialog(
      context,
      'update_required'.tr(),
      PopScope(
        canPop: false,
        child: Column(
          children: [
            Text('newer_version'.tr(), style: theme.textTheme.ppMori400White14),
            const SizedBox(height: 35),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'update'.tr(),
                    onTap: () {
                      final uri = Uri.tryParse(link);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future showReleaseNodeDialog(String releaseNotes) async {
    var screenKey =
        'what_new'.tr(); // avoid showing multiple what's new screens
    if (UIHelper.currentDialogTitle == screenKey) {
      return;
    }

    UIHelper.currentDialogTitle = screenKey;

    await _navigationService.navigateTo(
      AppRouter.releaseNotesPage,
      arguments: releaseNotes,
    );
  }

  @override
  Future openLatestVersion() async {
    final appStoreUrl =
        Platform.isIOS ? Constants.appStoreUrl : Constants.playStoreUrl;
    final uri = Uri.tryParse(appStoreUrl);
    if (uri != null) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    }
  }
}
