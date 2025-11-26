import 'dart:async';
import 'dart:io';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_rendering/feralfile_webview.dart';
import 'package:autonomy_flutter/nft_rendering/webview_controller_ext.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shake/shake.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PreviewPrimerPage extends StatefulWidget {
  final AssetToken token;

  const PreviewPrimerPage({
    required this.token,
    super.key,
  });

  @override
  State<PreviewPrimerPage> createState() => _PreviewPrimerPageState();
}

class _PreviewPrimerPageState extends State<PreviewPrimerPage>
    with AfterLayoutMixin, WidgetsBindingObserver {
  bool isFullScreen = false;
  ShakeDetector? _detector;
  WebViewController? _controller;
  final _configurationService = injector<ConfigurationService>();

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _detector?.stopListening();
    if (Platform.isAndroid) {
      unawaited(SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _detector = ShakeDetector.autoStart(
      onPhoneShake: (event) {
        setState(() {
          isFullScreen = false;
        });
        unawaited(SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        ));
      },
    );

    _detector?.startListening();

    WidgetsBinding.instance.addObserver(this);
  }

  Future _moveToInfo(AssetToken? assetToken) async {
    if (assetToken == null) {
      return;
    }
    unawaited(WakelockPlus.disable());
    Navigator.of(context).pop();
  }

  void onClickFullScreen(BuildContext context) {
    setState(() {
      isFullScreen = true;
    });
    unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColor.feralFileHighlight.withOpacity(0.9),
            borderRadius: BorderRadius.circular(64),
          ),
          child: Text(
            'shake_exit'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.ppMori600Black12,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = widget.token;
    final identityBloc = context.read<IdentityBloc>();
    final version = _configurationService.getVersionInfo();
    return Scaffold(
        appBar: isFullScreen
            ? null
            : AppBar(
                systemOverlayStyle: systemUiOverlayDarkStyle,
                backgroundColor: theme.colorScheme.primary,
                leadingWidth: 0,
                centerTitle: false,
                title: GestureDetector(
                  onTap: () => unawaited(_moveToInfo(token)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.displayTitle ?? '',
                        style: theme.textTheme.ppMori400White16,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      BlocBuilder<IdentityBloc, IdentityState>(
                        bloc: identityBloc
                          ..add(GetIdentityEvent([
                            token.artistName ?? '',
                          ])),
                        builder: (context, state) {
                          final artistName = token.artistName
                              ?.toIdentityOrMask(state.identityMap);
                          if (artistName != null) {
                            return Row(
                              children: [
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    'by'.tr(args: [artistName]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.ppMori400White14,
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(
                      maxWidth: 44,
                      maxHeight: 44,
                    ),
                    icon: Icon(
                      AuIcon.close,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    tooltip: 'close_icon',
                  )
                ],
              ),
        backgroundColor: theme.colorScheme.primary,
        body: SafeArea(
          top: false,
          bottom: false,
          left: !isFullScreen,
          right: !isFullScreen,
          child: Column(
            children: [
              Expanded(
                child: FeralFileWebview(
                  uri: Uri.parse(WEB3_PRIMER_URL),
                  userAgent: 'user_agent'.tr(namedArgs: {'version': version}),
                  onStarted: (controller) {
                    _controller = controller;
                  },
                  onLoaded: (controller) {
                    EasyDebounce.debounce(
                      'screen_rotate',
                      const Duration(milliseconds: 100),
                      () => unawaited(_controller?.evaluateJavascript(
                          source:
                              "window.dispatchEvent(new Event('resize'));")),
                    );
                  },
                ),
              ),
              Visibility(
                visible: !isFullScreen,
                child: Container(
                  color: theme.colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 30,
                      right: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => onClickFullScreen(context),
                          child: Semantics(
                            label: 'fullscreen_icon',
                            child: SvgPicture.asset(
                              'assets/images/fullscreen_icon.svg',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
