//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SunsetPage extends StatefulWidget {
  const SunsetPage({super.key});

  @override
  State<SunsetPage> createState() => _SunsetPageState();
}

class _SunsetPageState extends State<SunsetPage> {
  String? _title;
  String? _description;
  String? _downloadButtonText;
  String? _supportEmail;
  String? _iosAppStoreUrl;
  String? _androidAppStoreUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final remoteConfigService = injector<RemoteConfigService>();

      // Ensure config is loaded
      await remoteConfigService.loadConfigs();

      setState(() {
        _title = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.title,
          'This version of the Feral File app is now sunset.',
        );
        _description = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.description,
          'A new Feral File app is available with improved features and support.\n\nPlease download the new app to continue.',
        );
        _downloadButtonText = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.downloadButtonText,
          'Download the New Feral File App',
        );
        _supportEmail = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.supportEmail,
          'support@feralfile.com',
        );
        _iosAppStoreUrl = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.iosAppStoreUrl,
          'https://apps.apple.com/us/app/feral-file/id1544022728',
        );
        _androidAppStoreUrl = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.androidAppStoreUrl,
          'https://play.google.com/store/apps/details?id=com.bitmark.autonomy_client&pli=',
        );
        _isLoading = false;
      });
    } catch (e) {
      // If loading fails, use defaults
      setState(() {
        _title = 'This version of the Feral File app is now sunset.';
        _description =
            'A new Feral File app is available with improved features and support.\n\nPlease download the new app to continue.';
        _downloadButtonText = 'Download the New Feral File App';
        _supportEmail = 'support@feralfile.com';
        _iosAppStoreUrl = 'https://apps.apple.com/us/app/feral-file/id1544022728';
        _androidAppStoreUrl =
            'https://play.google.com/store/apps/details?id=com.bitmark.autonomy_client&pli=';
        _isLoading = false;
      });
    }
  }

  String get _appStoreUrl {
    if (Platform.isIOS) {
      return _iosAppStoreUrl ??
          'https://apps.apple.com/us/app/feral-file/id1544022728';
    } else if (Platform.isAndroid) {
      return _androidAppStoreUrl ??
          'https://play.google.com/store/apps/details?id=com.bitmark.autonomy_client&pli=';
    }

    return '';
  }

  Future<void> _openAppStore() async {
    final uri = Uri.parse(_appStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEmail() async {
    final email = _supportEmail ?? 'support@feralfile.com';
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback: copy email to clipboard or show error
      debugPrint('Could not launch email client');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AppColor.primaryBlack,
          extendBodyBehindAppBar: true,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColor.primaryBlack,
            child: SafeArea(
              child: _isLoading
                  ? const Center(
                      child: LoadingWidget(),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),

                          // Title
                          Text(
                            _title ??
                                'This version of the Feral File app is now sunset.',
                            style: theme.textTheme.ppMori700White24,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // Description
                          Text(
                            _description ??
                                'A new Feral File app is available with improved features and support.\n\nPlease download the new app to continue.',
                            style: theme.textTheme.ppMori400White14,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 48),

                          // Download Button
                          PrimaryButton(
                            text: _downloadButtonText ??
                                'Download the New Feral File App',
                            onTap: _openAppStore,
                            width: double.infinity,
                          ),

                          // Email Link
                          TextButton(
                            onPressed: _openEmail,
                            child: Text(
                              _supportEmail ?? 'support@feralfile.com',
                              style: theme.textTheme.ppMori400White14.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),

                          const Spacer(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
