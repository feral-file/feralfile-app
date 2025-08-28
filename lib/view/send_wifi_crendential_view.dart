import 'dart:async';

import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SendWifiCredentialView extends StatefulWidget {
  const SendWifiCredentialView({required this.onSend, super.key});

  final FutureOr<void> Function(String ssid, String password) onSend;

  @override
  State<SendWifiCredentialView> createState() => _SendWifiCredentialViewState();
}

class _SendWifiCredentialViewState extends State<SendWifiCredentialView> {
  final TextEditingController ssidController =
      TextEditingController(text: kDebugMode ? 'Bitmark' : '');

  final TextEditingController passwordController =
      TextEditingController(text: kDebugMode ? r'btmrkrckt@)@$' : '');

  @override
  void dispose() {
    passwordController.dispose();
    ssidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Please enter the Wi-Fi credentials '
          'that you want the Feral File device to connect to.',
          style: Theme.of(context).textTheme.ppMori400White14,
        ),
        const SizedBox(height: 30),
        TextField(
          controller: ssidController,
          style: Theme.of(context).textTheme.ppMori400White14,
          decoration: InputDecoration(
            labelText: 'Wi-Fi Name (SSID)',
            labelStyle: Theme.of(context).textTheme.ppMori400Grey14,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: passwordController,
          style: Theme.of(context).textTheme.ppMori400White14,
          decoration: InputDecoration(
            labelText: 'Wi-Fi Password',
            labelStyle: Theme.of(context).textTheme.ppMori400Grey14,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        PrimaryAsyncButton(
          onTap: () async {
            await widget.onSend(
              ssidController.text.trim(),
              passwordController.text.trim(),
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          text: 'Connect',
        ),
        const SizedBox(height: 16),
        OutlineButton(
          onTap: () async {
            Navigator.of(context).pop();
          },
          text: 'Cancel',
        ),
      ],
    );
  }
}
