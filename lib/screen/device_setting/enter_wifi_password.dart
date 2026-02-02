import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/error/bluetooth_response_error.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_exception.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gif_view/gif_view.dart';
import 'package:sentry/sentry.dart';

class SendWifiCredentialsPagePayload {
  const SendWifiCredentialsPagePayload({
    required this.wifiAccessPoint,
    required this.device,
    this.onSubmitted,
  });

  final WifiPoint wifiAccessPoint;
  final BluetoothDevice device;
  final FutureOr<void> Function(String? topicId, Object? error)? onSubmitted;
}

class SendWifiCredentialsPage extends StatefulWidget {
  const SendWifiCredentialsPage({
    required this.payload,
    super.key,
  });

  final SendWifiCredentialsPagePayload payload;

  @override
  State<SendWifiCredentialsPage> createState() =>
      SendWifiCredentialsPageState();
}

class SendWifiCredentialsPageState extends State<SendWifiCredentialsPage>
    with AfterLayoutMixin {
  late String _password;

  late final TextEditingController passwordController;

  bool _isProcessing = false;

  late FocusNode _passwordFocusNode;

  @override
  void initState() {
    super.initState();
    final isOpenNetwork = widget.payload.wifiAccessPoint.isOpenNetwork ?? false;
    _password = isOpenNetwork ? '' : (kDebugMode ? r'btmrkrckt@)@$' : '');
    passwordController = TextEditingController(text: _password);
    _passwordFocusNode = FocusNode();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    // set Timezone
    injector<FFBluetoothService>()
        .setTimezone(widget.payload.device)
        .catchError((Object e) {
      log.info('Failed to set timezone: $e');
      unawaited(
        Sentry.captureException(
          'Failed to set timezone: $e',
        ),
      );
    }).whenComplete(() {
      final isOpenNetwork =
          widget.payload.wifiAccessPoint.isOpenNetwork ?? false;
      if (isOpenNetwork) {
        _sendWifiCredentials();
      } else {
        _passwordFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SetupAppBar(
        title: 'select_network'.tr(),
      ),
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Padding(
          padding: ResponsiveLayout.pageEdgeInsets,
          child: _isProcessing
              ? _buildProcessingView()
              : (widget.payload.wifiAccessPoint.isOpenNetwork ?? false)
                  ? const SizedBox()
                  : Stack(
                      children: [
                        CustomScrollView(
                          slivers: [
                            const SliverToBoxAdapter(
                              child: SizedBox(
                                height: 120,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.payload.wifiAccessPoint.ssid,
                                    style: AppTypography.body(context).white,
                                  ),
                                  SizedBox(
                                    height: LayoutConstants.space4,
                                  ),
                                  PasswordTextField(
                                    controller: passwordController,
                                    focusNode: _passwordFocusNode,
                                    style: AppTypography.body(context).white,
                                    hintText: widget.payload.wifiAccessPoint
                                                .isOpenNetwork ==
                                            null
                                        ? 'Password (optional)'
                                        : 'Password',
                                    defaultObscure: false,
                                    isEnabled: !_isProcessing,
                                    onChanged: (value) {
                                      setState(() {
                                        _password = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: LayoutConstants.space4,
                          left: 0,
                          right: 0,
                          child: PrimaryAsyncButton(
                            padding: const EdgeInsets.only(top: 13, bottom: 10),
                            enabled: true,
                            onTap: _sendWifiCredentials,
                            color: AppColor.white,
                            text: 'submit'.tr(),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GifView.asset(
            'assets/images/loading.gif',
            width: 139,
            height: 92.67,
            frameRate: 12,
          ),
          SizedBox(height: LayoutConstants.space16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Connecting to ',
                  style: AppTypography.h2(context).white.regular,
                ),
                TextSpan(
                  text: widget.payload.wifiAccessPoint.ssid,
                  style: AppTypography.h2(context).white.bold,
                ),
                TextSpan(
                  text: '...',
                  style: AppTypography.h2(context).white.regular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWifiCredentials() async {
    final ssid = widget.payload.wifiAccessPoint.ssid;
    final isOpenNetwork = widget.payload.wifiAccessPoint.isOpenNetwork ?? false;
    final password = isOpenNetwork ? '' : passwordController.text.trim();
    var bleDevice = widget.payload.device;
    setState(() {
      _isProcessing = true;
    });
    try {
      // Check if the device is connected
      if (!bleDevice.isConnected) {
        if (bleDevice is FFBluetoothDevice && bleDevice.remoteID.isEmpty) {
          bleDevice =
              await injector<FFBluetoothService>().scanAndConnect(bleDevice);
        } else {
          await injector<FFBluetoothService>().connectToDevice(bleDevice);
        }
      }

      final topicId = await injector<FFBluetoothService>().sendWifiCredentials(
        device: bleDevice,
        ssid: ssid,
        password: password,
      );

      if (topicId == null) {
        throw FailedToConnectToWifiException(ssid, bleDevice);
      }
      await widget.payload.onSubmitted?.call(topicId, null);
    } on FailedToConnectToWifiException catch (e) {
      log.info('Failed to connect to wifi: $e');
      unawaited(
        Sentry.captureException(
          e,
        ),
      );
      unawaited(
        UIHelper.showInfoDialog(
          context,
          'Couldn\'t connect to Wi‑Fi',
          'FF1 couldn\'t connect to ${e.ssid}. Check the password and signal strength, then try again.',
        ).then((_) {
          if (isOpenNetwork) {
            injector<NavigationService>().goBack();
          }
        }),
      );
    } on FFBluetoothResponseError catch (e) {
      log.info('Failed to send wifi credentials: $e');
      unawaited(
        Sentry.captureException(
          'SendWifiCredentialError: ${e.title}: ${e.message} ($e)',
        ),
      );
      if (e is DeviceVersionCheckFailedError) {
        unawaited(
          UIHelper.showInfoDialog(
            context,
            e.title,
            e.message,
            closeButton: 'Contact support',
            onClose: () async {
              await injector<NavigationService>().showCustomerSupport();
            },
          ).then((_) {
            widget.payload.onSubmitted?.call(null, e);
          }),
        );
        return;
      } else if (e is DeviceUpdatingError) {
        unawaited(
          injector<NavigationService>().navigateTo(
            AppRouter.ff1Updating,
          ),
        );
        return;
      } else {
        unawaited(
          UIHelper.showInfoDialog(
            context,
            e.title,
            e.message,
          ).then(
            (_) {
              if (isOpenNetwork) {
                injector<NavigationService>().goBack();
              }
            },
          ),
        );
      }
    } on TimeoutException catch (e) {
      log.info('Failed to send wifi credentials: $e');
      unawaited(
        Sentry.captureException(
          'Failed to send wifi credentials: $e',
        ),
      );
      unawaited(
        UIHelper.showInfoDialog(
          context,
          'Can\'t reach FF1',
          'FF1 didn\'t respond in time. Make sure FF1 is nearby and try again.',
        ).then((_) {
          widget.payload.onSubmitted?.call(null, e);
        }),
      );
    } catch (e) {
      log.info('Failed to send wifi credentials: $e');
      unawaited(
        Sentry.captureException(
          'Failed to send wifi credentials: $e',
        ),
      );
      unawaited(
        UIHelper.showInfoDialog(
          context,
          'Wi‑Fi setup failed',
          'FF1 couldn\'t complete Wi‑Fi setup because of an unexpected issue. Contact support for help.',
          closeButton: 'Contact support',
          onClose: () async {
            injector<NavigationService>().showCustomerSupport();
          },
        ).then((_) {
          widget.payload.onSubmitted?.call(null, e);
        }),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

// class PasswordTextField, to enter password, with button to change the visibility of the password

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    required this.controller,
    super.key,
    this.defaultObscure = true,
    this.style,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onVisibilityChanged,
    this.isEnabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final TextStyle? style;
  final bool defaultObscure;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<bool>? onVisibilityChanged;
  final bool isEnabled;
  final FocusNode? focusNode;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  late bool _isObscure;

  @override
  void initState() {
    super.initState();
    _isObscure = widget.defaultObscure;
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = AppColor.primaryBlack;
    return TextField(
      focusNode: widget.focusNode,
      autocorrect: false,
      enableSuggestions: false,
      controller: widget.controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      obscureText: _isObscure,
      style: widget.style,
      enabled: widget.isEnabled,
      decoration: InputDecoration(
        // border radius 10
        hintText: widget.hintText,
        hintStyle: widget.style,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        fillColor: backgroundColor,
        focusColor: backgroundColor,
        filled: true,
        constraints: const BoxConstraints(minHeight: 60),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscure ? Icons.visibility_off : Icons.visibility,
            color: AppColor.greyMedium,
          ),
          onPressed: () {
            setState(() {
              _isObscure = !_isObscure;
              widget.onVisibilityChanged?.call(_isObscure);
            });
          },
        ),
      ),
    );
  }
}
