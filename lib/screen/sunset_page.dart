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
import 'package:flutter/gestures.dart';
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
          '',
        );
        _description = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.description,
          '',
        );
        _downloadButtonText = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.downloadButtonText,
          '',
        );
        _supportEmail = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.supportEmail,
          '',
        );
        _iosAppStoreUrl = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.iosAppStoreUrl,
          '',
        );
        _androidAppStoreUrl = remoteConfigService.getConfig<String>(
          ConfigGroup.sunset,
          ConfigKey.androidAppStoreUrl,
          '',
        );
        _isLoading = false;
      });
    } catch (e) {
      // If loading fails, use defaults
      setState(() {
        _title = 'Feral File Legacy App: End of Support';
        _description =
            // ignore: lines_longer_than_80_chars
            'This version of the Feral File app is being retired in December 2025.\n\nWe\'ve rebuilt the app under our new company to focus on FF1 and daily digital art, so some settings (like saved addresses) need to be set up again. Your artworks and NFTs remain in your own wallets.\n\nTo use Feral File with FF1 and future exhibitions, please install our new app, Feral File, from this app store (subtitle: "Digital art & FF1 controller"). After you sign in there, you can re-add any wallet or account addresses you\'d like us to index.\n\nIf you need help, email support@feralfile.com.';
        _supportEmail = 'support@feralfile.com';
        _isLoading = false;
      });
    }
  }

  String get _appStoreUrl {
    if (Platform.isIOS) {
      return _iosAppStoreUrl ?? '';
    } else if (Platform.isAndroid) {
      return _androidAppStoreUrl ?? '';
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

  TextSpan _buildDescriptionTextSpan(String text, TextStyle baseStyle) {
    final emailPattern = _supportEmail ?? 'support@feralfile.com';

    // Build list of text spans handling all occurrences of the email
    final spans = <TextSpan>[];
    var lastIndex = 0;
    var emailIndex = text.indexOf(emailPattern, lastIndex);

    if (emailIndex == -1) {
      // No email found, return simple text span
      return TextSpan(text: text, style: baseStyle);
    }

    while (emailIndex != -1 && lastIndex < text.length) {
      // Add text before email
      if (emailIndex > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, emailIndex),
            style: baseStyle,
          ),
        );
      }

      // Add clickable email
      spans.add(
        TextSpan(
          text: emailPattern,
          style: baseStyle.copyWith(
            decoration: TextDecoration.underline,
            color: AppColor.white,
          ),
          recognizer: TapGestureRecognizer()..onTap = _openEmail,
        ),
      );

      lastIndex = emailIndex + emailPattern.length;
      emailIndex = text.indexOf(emailPattern, lastIndex);
    }

    // Add remaining text after last email
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }

    return TextSpan(children: spans);
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
                          if (_title != null && _title!.isNotEmpty) ...[
                            // Title
                            Text(
                              _title!,
                              style: theme.textTheme.ppMori700White24,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                          ],
                          if (_description != null &&
                              _description!.isNotEmpty) ...[
                            // Description
                            RichText(
                              text: _buildDescriptionTextSpan(
                                _description!,
                                theme.textTheme.ppMori400White14,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                          if (_downloadButtonText != null &&
                              _downloadButtonText!.isNotEmpty) ...[
                            const SizedBox(height: 48),
                            PrimaryButton(
                              text: _downloadButtonText,
                              onTap: _openAppStore,
                              width: double.infinity,
                            ),
                          ],
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
