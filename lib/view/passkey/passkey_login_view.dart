import 'dart:async';

import 'package:autonomy_flutter/model/jwt.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/passkey/having_trouble_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class PasskeyLoginRetryView extends StatefulWidget {
  final Future<JWT?> Function() onRetry;

  const PasskeyLoginRetryView({required this.onRetry, super.key});

  @override
  State<PasskeyLoginRetryView> createState() => _PasskeyLoginRetryViewState();
}

class _PasskeyLoginRetryViewState extends State<PasskeyLoginRetryView> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _getTitle(context),
              const SizedBox(height: 20),
              _getDesc(context),
            ],
          ),
          const SizedBox(height: 20),
          _getIcon(),
          const SizedBox(height: 20),
          _getAction(context),
          const SizedBox(height: 20),
          const HavingTroubleView(),
        ],
      );

  Widget _getTitle(BuildContext context) => Text(
        'authentication_failed'.tr(),
        style: Theme.of(context).textTheme.ppMori700Black16,
      );

  Widget _getDesc(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.ppMori400Black14;
    return Text(
      'passkey_error_desc'.tr(),
      style: style,
    );
  }

  Widget _getIcon() => SvgPicture.asset(
        'assets/images/passkey_icon.svg',
      );

  Widget _getAction(BuildContext context) => PrimaryAsyncButton(
        key: const Key('login_button'),
        color: AppColor.feralFileLightBlue,
        onTap: _login,
        text: 'try_again'.tr(),
      );

  Future<void> _login() async {
    if (_isRetrying) {
      return;
    }
    setState(() {
      _isRetrying = true;
    });
    try {
      final res = await widget.onRetry();
      if (mounted) {
        Navigator.of(context).pop(res);
      }
    } catch (e, stackTrace) {
      log.info('Failed to login with passkey: $e');
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    } finally {
      setState(() {
        _isRetrying = false;
      });
    }
  }
}
