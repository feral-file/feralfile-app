//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/feralfile_docs_api.dart';
import 'package:autonomy_flutter/gateway/pubdoc_api.dart';
import 'package:autonomy_flutter/model/version_info.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/helpers.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum VersionCompatibilityResult {
  compatible,
  needUpdateApp,
  needUpdateDevice,
  unknown,
  deviceNotFound;

  bool get isValid =>
      this != VersionCompatibilityResult.needUpdateApp &&
      this != VersionCompatibilityResult.needUpdateDevice;
}

abstract class VersionService {
  Future<void> checkForUpdate();

  Future<String?> getReleaseNote(String? changeLog, String? date);

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
    this._feralfileDocAPI,
    this._configurationService,
    this._navigationService,
  );

  final PubdocAPI _pubdocAPI;
  final FeralFileDocsAPI _feralfileDocAPI;
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
  Future<void> checkForUpdate() async {
    if (kDebugMode) {
      return;
    }
    if (UIHelper.currentDialogTitle == 'update_required'.tr()) {
      return;
    }

    final versionInfo = await getVersionInfo();
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (compareVersion(versionInfo.requiredVersion, currentVersion) > 0) {
      await showForceUpdateDialog(versionInfo.link);
    } else {
      // check to show the latest release notes
      await showLatestReleaseNote();
    }
  }

  Future<void> showLatestReleaseNote() async {
    try {
      final changeLog = await _feralfileDocAPI.getChangeLog();
      final latestDate = _getLatestVersionDate(changeLog);
      if (latestDate == null) {
        return;
      }

      var readDate = _configurationService.getReadReleaseNotesVersion();

      // Don't show release notes for new users
      if (readDate == null) {
        unawaited(
          _configurationService.setReadReleaseNotesInVersion(latestDate),
        );
        return;
      }

      // Handle backward compatibility: if stored value is a version, ignore it
      if (RegExp(r'^\d+\.\d+\.\d+').hasMatch(readDate)) {
        // Old version format, treat as not read
        readDate = null;
        unawaited(
          _configurationService.setReadReleaseNotesInVersion(latestDate),
        );
      }

      if (readDate != null) {
        // Check if user has already read this date or a newer date
        final hasReadNewerDate =
            compareReleaseNoteDates(changeLog, readDate, latestDate) >= 0;
        if (hasReadNewerDate) {
          // Already read this date or newer, mark latest date as read
          unawaited(
            _configurationService.setReadReleaseNotesInVersion(latestDate),
          );
          return;
        }
      }

      // User has read release notes before but not this latest date
      // Show the latest release notes
      final releaseNote = _getReleaseNoteByDate(changeLog, latestDate);
      if (releaseNote == null) {
        return;
      }

      await showReleaseNodeDialog(releaseNote);
    } catch (_) {
      // On error, silently return
    }
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

  @override
  Future<String?> getReleaseNote(String? changeLog, String? date) async {
    try {
      var releaseNotes = changeLog;
      releaseNotes ??= await _feralfileDocAPI.getChangeLog();

      String? releaseNote;
      if (date != null) {
        releaseNote = _getReleaseNoteByDate(releaseNotes, date);
      }

      return releaseNote;
    } catch (_) {
      return null;
    }
  }

  String? _getLatestVersionDate(String changeLog) {
    final lines = changeLog.split('\n');

    // Find the first version date header (##)
    // Changelog is ordered newest to oldest
    for (final line in lines) {
      if (isReleaseNoteDateHeader(line)) {
        return line.replaceFirst(RegExp(r'^##\s*'), '').trim();
      }
    }

    return null;
  }

  /// Gets release note for a specific date from changelog
  /// Returns null if date not found
  String? _getReleaseNoteByDate(String changeLog, String date) {
    final lines = changeLog.split('\n');
    int? dateHeaderIndex;

    // Find the date header
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (isReleaseNoteDateHeader(line)) {
        final dateStr = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
        if (dateStr == date) {
          dateHeaderIndex = i;
          break;
        }
      }
    }

    if (dateHeaderIndex == null) {
      return null;
    }

    // Find where this date section ends (next date header ## or end of file)
    var dateSectionEnd = lines.length;
    for (var i = dateHeaderIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (isReleaseNoteDateHeader(line)) {
        dateSectionEnd = i;
        break;
      }
    }

    // Extract the entire date section (including FF OS and Mobile App)
    final sectionLines = lines.sublist(dateHeaderIndex, dateSectionEnd);

    return sectionLines.join('\n').trim();
  }

  Future<void> showForceUpdateDialog(String link) async {
    final context = _navigationService.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final theme = Theme.of(context);
    await UIHelper.showDialog<void>(
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

  Future<void> showReleaseNodeDialog(String releaseNote) async {
    final screenKey =
        'what_new'.tr(); // avoid showing multiple what's new screens
    if (UIHelper.currentDialogTitle == screenKey) {
      return;
    }

    UIHelper.currentDialogTitle = screenKey;

    await _navigationService.navigateTo(
      AppRouter.releaseNotesPage,
      arguments: releaseNote,
    );
  }

  @override
  Future<void> openLatestVersion() async {
    final appStoreUrl =
        Platform.isIOS ? Constants.appStoreUrl : Constants.playStoreUrl;
    final uri = Uri.tryParse(appStoreUrl);
    if (uri != null) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    }
  }
}
