//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart' as log_util;
import 'package:autonomy_flutter/util/native_log_reader.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/au_buttons.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/badge_view.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/tappable_forward_row.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class SupportCustomerPage extends StatefulWidget {
  const SupportCustomerPage({super.key});

  @override
  State<SupportCustomerPage> createState() => _SupportCustomerPageState();
}

class _SupportCustomerPageState extends State<SupportCustomerPage>
    with RouteAware, WidgetsBindingObserver {
  bool _isDocsVisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(injector<CustomerSupportService>().getChatThreads());
    // Trigger fade in animation after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isDocsVisible = true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    unawaited(injector<CustomerSupportService>().getChatThreads());
    super.didPopNext();
  }

  @override
  void dispose() {
    super.dispose();
    routeObserver.unsubscribe(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'how_can_we_help'.tr(),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            addTitleSpace(),
            Padding(
              padding: ResponsiveLayout.pageHorizontalEdgeInsets,
              child: _reportItemsWidget(),
            ),
            const SizedBox(height: 30),
            addOnlyDivider(),
            _resourcesWidget(),
          ],
        ),
      ),
    );
  }

  Widget _reportItemsWidget() => Column(
        children: [
          ...ReportIssueType.getSuggestList.map(
            (item) => Column(
              children: [
                AuSecondaryButton(
                  text: ReportIssueType.toTitle(item),
                  onPressed: () async {
                    await Navigator.of(context).pushNamed(
                      AppRouter.supportThreadPage,
                      arguments: NewIssuePayload(reportIssueType: item),
                    );
                  },
                  backgroundColor: Colors.white,
                  borderColor: AppColor.primaryBlack,
                  textColor: AppColor.primaryBlack,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          AuSecondaryButton(
            text: 'Contact us',
            onPressed: _handleContactUs,
            backgroundColor: Colors.white,
            borderColor: AppColor.primaryBlack,
            textColor: AppColor.primaryBlack,
          ),
        ],
      );

  Widget _resourcesWidget() {
    return ValueListenableBuilder<List<int>?>(
      valueListenable: injector<CustomerSupportService>().numberOfIssuesInfo,
      builder: (
        BuildContext context,
        List<int>? numberOfIssuesInfo,
        Widget? child,
      ) {
        if (numberOfIssuesInfo == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (numberOfIssuesInfo[0] == 0) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TappableForwardRow(
              leftWidget: Row(
                children: [
                  Text(
                    'support_history'.tr(),
                    style: AppTypography.body(context).black,
                  ),
                  if (numberOfIssuesInfo[1] > 0) ...[
                    const SizedBox(
                      width: 7,
                    ),
                    redDotIcon(),
                  ],
                ],
              ),
              rightWidget: numberOfIssuesInfo[1] > 0
                  ? BadgeView(number: numberOfIssuesInfo[1])
                  : null,
              onTap: () async {
                await Navigator.of(context)
                    .pushNamed(AppRouter.supportListPage);
              },
              padding: ResponsiveLayout.tappableForwardRowEdgeInsets,
            ),
            addOnlyDivider(),
          ],
        );
      },
    );
  }

  Future<void> _handleContactUs() async {
    if (!mounted) {
      return;
    }

    unawaited(
      UIHelper.showDialog<void>(
        context,
        'attach_crash_log'.tr(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ask_attach_crash'.tr(),
              style: AppTypography.body(context).white,
            ),
            SizedBox(height: LayoutConstants.space10),
            PrimaryButton(
              text: 'attach_crash_logH'.tr(),
              onTap: () => _onConfirmAttachCrashLog(true),
            ),
            SizedBox(height: LayoutConstants.space3),
            OutlineButton(
              text: 'conti_no_crash_log'.tr(),
              onTap: () => _onConfirmAttachCrashLog(false),
            ),
            SizedBox(height: LayoutConstants.space10),
          ],
        ),
        isDismissible: true,
      ),
    );
  }

  void _onConfirmAttachCrashLog(bool attachCrashLog) {
    try {
      UIHelper.hideInfoDialog(context);
    } catch (e) {
      log_util.log.warning('Failed to hide attach crash log dialog: $e');
    }

    unawaited(_sendSupportEmail(attachLogs: attachCrashLog));
  }

  Future<void> _sendSupportEmail({required bool attachLogs}) async {
    try {
      if (!mounted) {
        return;
      }

      UIHelper.showDialog<void>(
        context,
        'Preparing log files...',
        const Center(child: CupertinoActivityIndicator()),
      );

      final logFiles = attachLogs ? await _collectLogFiles() : <File>[];

      if (!mounted) {
        return;
      }
      UIHelper.hideInfoDialog(context);

      if (attachLogs && logFiles.isEmpty) {
        await UIHelper.showInfoDialog(
          context,
          'No log files available',
          'Unable to collect log files. Please try again later.',
        );
      }

      // Get app version for subject
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final subject = 'Support Request - $appVersion ($buildNumber)';
      final baseText =
          'Please describe your issue here.\n\nApp Version: $appVersion\nBuild Number: $buildNumber';
      final emailBody = attachLogs
          ? '$baseText\n\nLog files are attached.'
          : '$baseText\n\nLogs are not attached.';

      final email = Email(
        body: emailBody,
        subject: subject,
        recipients: const ['support@feralfile.com'],
        cc: const ['sang@feralfile.com'],
        attachmentPaths: logFiles.map((file) => file.path).toList(),
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
    } catch (e) {
      log_util.log.severe('Failed to handle contact us: $e');
      if (!mounted) {
        return;
      }
      UIHelper.hideInfoDialog(context);
      await UIHelper.showInfoDialog(
        context,
        'Error',
        'Failed to prepare email. Please try again later.',
      );
    }
  }

  Future<List<File>> _collectLogFiles() async {
    final List<File> logFiles = [];
    const fileMaxSize = 1024 * 1024; // 1MB

    // Get Flutter logs
    try {
      final file = await log_util.getLogFile();
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        var combinedBytes = bytes;
        if (combinedBytes.length > fileMaxSize) {
          combinedBytes =
              combinedBytes.sublist(combinedBytes.length - fileMaxSize);
        }
        if (combinedBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/flutter_${combinedBytes.length}_${DateTime.now().microsecondsSinceEpoch}.logs',
          );
          await tempFile.writeAsBytes(combinedBytes);
          logFiles.add(tempFile);
        }
      }
    } catch (e) {
      log_util.log.severe('Failed to get Flutter log: $e');
    }

    // Get native logs (Android only)
    try {
      if (Platform.isAndroid) {
        final nativeLogContent = await NativeLogReader.getLogContent();
        final nativeLogBytes = utf8.encode(nativeLogContent);
        var nativeLogCombinedBytes = nativeLogBytes;
        if (nativeLogCombinedBytes.length > fileMaxSize) {
          nativeLogCombinedBytes = nativeLogCombinedBytes
              .sublist(nativeLogCombinedBytes.length - fileMaxSize);
        }
        if (nativeLogCombinedBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/native_${nativeLogCombinedBytes.length}_${DateTime.now().microsecondsSinceEpoch}.logs',
          );
          await tempFile.writeAsBytes(nativeLogCombinedBytes);
          logFiles.add(tempFile);
        }
      }
    } catch (e) {
      log_util.log.severe('Failed to get native log: $e');
    }

    // Add account settings audit log
    try {
      final accountSettingsAudit = await _generateAccountSettingsAudit();
      final auditBytes = utf8.encode(accountSettingsAudit);
      if (auditBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/account_settings_audit_${auditBytes.length}_${DateTime.now().microsecondsSinceEpoch}.json',
        );
        await tempFile.writeAsBytes(auditBytes);
        logFiles.add(tempFile);
      }
    } catch (e) {
      log_util.log.severe('Failed to get account settings audit: $e');
    }

    return logFiles;
  }

  Future<String> _generateAccountSettingsAudit() async {
    try {
      final appDataManager = injector<AppDataManager>();

      // Gather account settings with privacy protection
      final auditData = <String, dynamic>{
        'app_preferences': _gatherAppPreferences(appDataManager),
        'addresses_import_history': _gatherAccountHistory(appDataManager),
      };

      // Convert to JSON with pretty printing
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(auditData);
    } catch (e) {
      log_util.log.severe('Failed to generate account settings audit: $e');
      return '{"error": "Failed to generate account settings audit: $e"}';
    }
  }

  Map<String, dynamic> _gatherAppPreferences(AppDataManager appDataManager) {
    try {
      final settingsService = appDataManager.appSettingsStorageService;

      return {
        'analytics_enabled': settingsService.isAnalyticsEnabled,
        'notification_enabled': settingsService.isNotificationEnabled,
        'device_passcode_enabled': settingsService.isDevicePasscodeEnabled,
        'beta_features_enabled': settingsService.isBetaFeaturesEnabled,
        'explore_bar_enabled': settingsService.isExploreBarEnabled,
        'hidden_token_count': settingsService.hiddenTokenIDs.length,
        'selected_device_id': settingsService.selectedDeviceId ?? 'none',
      };
    } catch (e) {
      log_util.log.warning('Failed to gather app preferences: $e');
      return {'error': 'Unable to retrieve preferences'};
    }
  }

  Map<String, dynamic> _gatherAccountHistory(AppDataManager appDataManager) {
    try {
      final addressService = appDataManager.addressStorageService;

      // Get address-related info without exposing private keys
      final addresses = addressService.getAllAddresses();

      return {
        'total_addresses': addresses.length,
        'address_details': addresses
            .map((addr) => {
                  'type': addr.cryptoType.toString(),
                  'created_at': addr.createdAt.toIso8601String(),
                  'is_hidden': addr.isHidden,
                  'name': addr.name,
                  // Redact actual address for privacy
                  'address_preview': _redactAddress(addr.address),
                })
            .toList(),
      };
    } catch (e) {
      log_util.log.warning('Failed to gather account history: $e');
      return {'error': 'Unable to retrieve account history'};
    }
  }

  String _redactAddress(String address) {
    // Show first 6 and last 4 characters only, redact the middle
    if (address.length <= 10) {
      return '***';
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
