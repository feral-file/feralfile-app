import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/jwt.dart';
import 'package:autonomy_flutter/service/passkey_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/dio_exception_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/passkey/having_trouble_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum PasskeyRegisterViewType {
  register,
  login,
}

class PasskeyRegisterView extends StatefulWidget {
  const PasskeyRegisterView({super.key});

  @override
  State<PasskeyRegisterView> createState() => _PasskeyRegisterViewState();
}

class _PasskeyRegisterViewState extends State<PasskeyRegisterView> {
  final _passkeyService = injector.get<PasskeyService>();

  Object? _error;
  bool _registering = false;
  PasskeyRegisterViewType? _type;
  bool _didSuccess = false;
  JWT? _jwt;

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
          ..._havingTrouble(context),
        ],
      );

  Widget _getTitle(BuildContext context) => Text(
        _didSuccess
            ? 'passkey_created'.tr()
            : _error != null
                ? 'authentication_failed'.tr()
                : 'introducing_passkey'.tr(),
        style: Theme.of(context).textTheme.ppMori700Black16,
      );

  Widget _getDesc(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.ppMori400Black14;
    if (_didSuccess) {
      return Column(
        children: [
          Text(
            'passkey_created_desc'.tr(),
            style: style,
          ),
        ],
      );
    }
    if (_error != null) {
      return Column(
        children: [
          if (_error is DioException &&
              ((_error! as DioException).statusCode ==
                  StatusCode.notFound.value) &&
              (_error! as DioException).ffErrorCode == 998) ...[
            Text(
              'passkey_not_found'.tr(),
              style: style,
            ),
          ] else ...[
            Text(
              'passkey_error_desc'.tr(),
              style: style,
            ),
          ],
        ],
      );
    }
    return Text(
      'introducing_passkey_desc_1'.tr(),
      style: style,
    );
  }

  Widget _getIcon() {
    if (_didSuccess) {
      return SvgPicture.asset(
        'assets/images/selected_round.svg',
      );
    }
    return SvgPicture.asset(
      'assets/images/passkey_icon.svg',
    );
  }

  Widget _getAction(BuildContext context) {
    if (_didSuccess) {
      return PrimaryButton(
        text: 'continue'.tr(),
        color: AppColor.feralFileLightBlue,
        onTap: () async {
          Navigator.of(context).pop(_jwt);
        },
      );
    }

    if (_error != null) {
      return Column(
        children: [
          PrimaryAsyncButton(
            key: const Key('try_again_button'),
            color: AppColor.feralFileLightBlue,
            onTap: () {
              if (_type == PasskeyRegisterViewType.register) {
                return _register();
              } else {
                return _login();
              }
            },
            text: 'try_again'.tr(),
            processingText: 'processing'.tr(),
          ),
        ],
      );
    }
    return Column(
      children: [
        PrimaryAsyncButton(
          key: const Key('register_button'),
          color: AppColor.feralFileLightBlue,
          onTap: () async {
            _type = PasskeyRegisterViewType.register;
            final jwt = await _register();
            return jwt;
          },
          text: 'get_started'.tr(),
          processingText: 'creating_passkey'.tr(),
        ),
        const SizedBox(height: 20),
        TextAsyncButton(
          key: const Key('login_button'),
          color: AppColor.auQuickSilver,
          onTap: () async {
            _type = PasskeyRegisterViewType.login;
            final jwt = await _login();
            return jwt;
          },
          text: 'login_with_passkey'.tr(),
          processingText: 'login_with_passkey'.tr(),
        ),
      ],
    );
  }

  Future<JWT?> _register() async {
    JWT? jwt;
    if (_registering) {
      return null;
    }
    setState(() {
      _registering = true;
    });
    try {
      await _passkeyService.registerInitiate();
      jwt = await _passkeyService.registerFinalize();
      setState(() {
        _didSuccess = true;
        _jwt = jwt;
      });
    } catch (e, stackTrace) {
      log.info('Failed to register passkey: $e');
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      setState(() {
        _error = e;
      });
    } finally {
      setState(() {
        _registering = false;
      });
    }
    return jwt;
  }

  Future<JWT?> _login() async {
    JWT? jwt;
    if (_registering) {
      return null;
    }
    setState(() {
      _registering = true;
    });
    try {
      final jwt = await _passkeyService.requestJwt();
      if (context.mounted) {
        Navigator.of(context).pop(jwt);
      }
    } catch (e, stackTrace) {
      log.info('Failed to login passkey: $e');
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      setState(() {
        _error = e;
      });
    } finally {
      setState(() {
        _registering = false;
      });
    }
    return jwt;
  }

  List<Widget> _havingTrouble(BuildContext context) {
    if (_didSuccess || (_error == null && !_registering)) {
      return const [];
    }
    return [
      const SizedBox(height: 20),
      const HavingTroubleView(),
    ];
  }
}
