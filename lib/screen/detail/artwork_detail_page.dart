//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:collection';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/screen/detail/preview_detail/preview_detail_widget.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_item_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/canvas_playing_ext.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/util/feral_file_custom_tab.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/webview_controller_text_field.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/artwork_playing_controls/artwork_playing_controls.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:backdrop/backdrop.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:sentry/sentry.dart';
import 'package:shake/shake.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ArtworkDetailPage extends StatefulWidget {
  const ArtworkDetailPage({required this.payload, super.key});

  final ArtworkDetailPayload payload;

  @override
  State<ArtworkDetailPage> createState() => _ArtworkDetailPageState();
}

class _ArtworkDetailPageState extends State<ArtworkDetailPage>
    with
        AfterLayoutMixin<ArtworkDetailPage>,
        RouteAware,
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver {
  ValueNotifier<double> downloadProgress = ValueNotifier(0);

  HashSet<String> _accountNumberHash = HashSet.identity();
  AssetToken? currentToken;
  final _focusNode = FocusNode();
  final _textController = TextEditingController();
  WebViewController? _webViewController;
  bool _isInfoExpand = false;
  static const _infoShrinkPosition = 0.001;
  static const _infoExpandPosition = 0.29;
  static const _infoHeaderHeight = 68;
  late ArtworkDetailBloc _bloc;
  late CanvasDeviceBloc _canvasDeviceBloc;
  late AnimationController _animationController;
  double? _appBarBottomDy;
  bool _isFullScreen = false;
  ShakeDetector? _detector;
  bool _previousBottomSheetVisibility = false;

  final FocusNode _selectTextFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    CustomRouteObserver.bottomSheetVisibility.value = false;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
      value: _infoShrinkPosition,
      upperBound: _infoExpandPosition,
    );
    _infoShrink();
    _bloc = context.read<ArtworkDetailBloc>();
    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
    _bloc.add(
      ArtworkDetailGetInfoEvent(
        widget.payload.identity,
        useIndexer: widget.payload.useIndexer,
      ),
    );
    context.read<AccountsBloc>().add(FetchAllAddressesEvent());
    context.read<AccountsBloc>().add(GetAccountsEvent());
  }

  @override
  void afterFirstLayout(BuildContext context) {
    WidgetsBinding.instance.addObserver(this);
    const appBarHeight = kToolbarHeight + 20;
    _appBarBottomDy ??= appBarHeight + MediaQuery.of(context).padding.top;
    _detector = ShakeDetector.autoStart(
      onPhoneShake: (event) async {
        await _exitFullScreen();
      },
    );
  }

  @override
  void didChangeDependencies() {
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    _textController.dispose();
    unawaited(disableLandscapeMode());
    unawaited(WakelockPlus.disable());
    _detector?.stopListening();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
    super.dispose();
  }

  @override
  void didPop() {
    CustomRouteObserver.bottomSheetVisibility.value = false;
    super.didPop();
  }

  @override
  void didPopNext() {
    CustomRouteObserver.bottomSheetVisibility.value = false;
    super.didPopNext();
  }

  void _infoShrink() {
    setState(() {
      _isInfoExpand = false;
      CustomRouteObserver.bottomSheetVisibility.value = false;
    });
    _selectTextFocusNode.unfocus();
    _animationController.animateTo(_infoShrinkPosition);
  }

  void _infoExpand() {
    setState(() {
      _isInfoExpand = true;
      CustomRouteObserver.bottomSheetVisibility.value = true;
    });
    _animationController.animateTo(_infoExpandPosition);
  }

  @override
  Widget build(BuildContext context) {
    final hasKeyboard = currentToken?.canInteract;
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: BlocConsumer<ArtworkDetailBloc, ArtworkDetailState>(
        listener: (context, state) {
          final identitiesList = state.assetToken?.provenance
                  .map((e) => e.toAddress ?? '')
                  .toSet()
                  .toList() ??
              [];
          final listArtists = state.assetToken?.getArtists;
          identitiesList
            ..addAll(listArtists?.map((e) => e.name) ?? [])
            ..addAll(
              state.assetToken?.owners?.items.map((e) => e.ownerAddress) ?? [],
            );

          setState(() {
            currentToken = state.assetToken;
          });
          context
              .read<IdentityBloc>()
              .add(GetIdentityEvent(identitiesList.toSet().toList()));
        },
        builder: (context, state) {
          final isLoading = state.assetToken == null;
          final identityState = context.watch<IdentityBloc>().state;
          final assetToken = state.assetToken;
          final artistName = assetToken?.getArtists.firstOrNull?.name
              .toIdentityOrMask(identityState.identityMap);
          return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
            bloc: _canvasDeviceBloc,
            builder: (context, canvasState) => Stack(
              children: [
                BackdropScaffold(
                  backgroundColor: AppColor.auGreyBackground,
                  resizeToAvoidBottomInset: hasKeyboard ?? false,
                  frontLayerElevation: _isFullScreen ? 0 : 1,
                  appBar: _isFullScreen
                      ? null
                      : MainAppBar(
                          backTitle: widget.payload.backTitle ?? '',
                          actions: [
                            if (!isLoading)
                              FFCastButton(
                                // displayKey: _getDisplayKey(assetToken),
                                onDeviceSelected: (device) async {
                                  final playlistItem =
                                      DP1PlaylistItemExtension.fromAssetToken(
                                    token: assetToken!,
                                  );
                                  final dp1Playlist =
                                      DP1CallExtension.fromItems(
                                    items: [playlistItem],
                                  );
                                  final completer = Completer<void>();
                                  _canvasDeviceBloc.add(
                                    CanvasDeviceCastDP1PlaylistEvent(
                                      intent: DP1Intent.displayNow(),
                                      device: device,
                                      playlist: dp1Playlist,
                                      usingUrl: false,
                                      onDoneCallback: () {
                                        completer.complete();
                                      },
                                    ),
                                  );
                                  await completer.future;
                                },
                              ),
                          ],
                        ),
                  backLayer: !isLoading
                      ? ArtworkBackLayer(
                          assetToken: assetToken!,
                          canvasDeviceBloc: _canvasDeviceBloc,
                          useIndexer: widget.payload.useIndexer,
                          identity: widget.payload.identity,
                          onLoaded: _onLoaded,
                          isFullScreen: _isFullScreen,
                        )
                      : LoadingWidget(
                          backgroundColor: AppColor.auGreyBackground),
                  reverseAnimationCurve: Curves.ease,
                  frontLayer: _isFullScreen || isLoading
                      ? const SizedBox()
                      : _infoContent(
                          context,
                          identityState,
                          state,
                          artistName,
                        ),
                  frontLayerBackgroundColor: _isFullScreen
                      ? Colors.transparent
                      : AppColor.auGreyBackground,
                  backLayerBackgroundColor: AppColor.auGreyBackground,
                  animationController: _animationController,
                  revealBackLayerAtStart: true,
                  frontLayerScrim: Colors.transparent,
                  backLayerScrim: Colors.transparent,
                  subHeaderAlwaysActive: false,
                  frontLayerShape: const BeveledRectangleBorder(),
                  subHeader: _isFullScreen || isLoading
                      ? null
                      : DecoratedBox(
                          decoration: const BoxDecoration(
                            color: AppColor.auGreyBackground,
                          ),
                          child: GestureDetector(
                            onVerticalDragEnd: (details) {
                              final dy = details.primaryVelocity ?? 0;
                              if (dy <= 0) {
                                _infoExpand();
                              } else {
                                _infoShrink();
                              }
                            },
                            child: Container(
                              child: _infoHeader(
                                context,
                                assetToken!,
                                artistName,
                                canvasState,
                              ),
                            ),
                          ),
                        ),
                ),
                if (_isInfoExpand && !_isFullScreen)
                  Positioned(
                    top: _appBarBottomDy ?? 80,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _infoShrink,
                      onVerticalDragEnd: (details) {
                        final dy = details.primaryVelocity ?? 0;
                        if (dy > 0) {
                          _infoShrink();
                        }
                      },
                      child: Container(
                        color: Colors.transparent,
                        height: (MediaQuery.of(context).size.height -
                                (_appBarBottomDy ?? 80) -
                                _infoHeaderHeight) *
                            0.5,
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  dynamic _onLoaded({WebViewController? webViewController, int? time}) {
    _webViewController = webViewController;
  }

  Widget _infoHeader(
    BuildContext context,
    AssetToken asset,
    String? artistName,
    CanvasDeviceState canvasState,
  ) {
    var subTitle = '';
    if (artistName != null && artistName.isNotEmpty) {
      subTitle = artistName;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
          child: Row(
            children: [
              Expanded(
                child: ArtworkDetailsHeader(
                  title: asset.displayTitle ?? '',
                  subTitle: subTitle,
                  onSubTitleTap: null,
                ),
              ),
              if (_isInfoExpand)
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _infoShrink,
                  constraints: const BoxConstraints(
                    maxWidth: 44,
                    maxHeight: 44,
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: const Icon(
                    AuIcon.close,
                    size: 18,
                    color: AppColor.white,
                  ),
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async => _showArtworkOptionsDialog(
                    context,
                    asset,
                    canvasState,
                  ),
                  constraints: const BoxConstraints(
                    maxWidth: 44,
                    maxHeight: 44,
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: SvgPicture.asset(
                    'assets/images/more_circle.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
            ],
          ),
        ),
        if (!_isInfoExpand) const BottomSpacing(),
      ],
    );
  }

  Widget _infoContent(
    BuildContext context,
    IdentityState identityState,
    ArtworkDetailState state,
    String? artistName,
  ) {
    final assetToken = state.assetToken!;
    final allAddresses = injector<AddressService>().getAllAddresses();
    final ownerItems = assetToken.owners?.items.where((element) =>
        allAddresses.contains(element.ownerAddress) &&
        (int.tryParse(element.quantity) ?? 0) > 0);
    return Stack(
      children: [
        Visibility(
          visible: true,
          child: WebviewControllerTextField(
            webViewController: _webViewController,
            focusNode: _focusNode,
            textController: _textController,
            disableKeys: assetToken.disableKeys,
          ),
        ),
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            // Consume scroll notifications to prevent them from bubbling up
            // to the main app's NotificationListener
            return true;
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Visibility(
                    visible: checkWeb3ContractAddress
                        .contains(assetToken.contractAddress),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 20),
                      child: OutlineButton(
                        color: Colors.transparent,
                        text: 'web3_glossary'.tr(),
                        onTap: () {
                          unawaited(
                            Navigator.pushNamed(
                              context,
                              AppRouter.previewPrimerPage,
                              arguments: assetToken,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: ResponsiveLayout.getPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: 'Desc',
                          child: SelectionArea(
                            focusNode: _selectTextFocusNode,
                            child: HtmlWidget(
                              customStylesBuilder: auHtmlStyle,
                              assetToken.displayDescription,
                              textStyle: AppTypography.body(context).white,
                              onTapUrl: (url) async {
                                await launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode.externalApplication,
                                );
                                return true;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        artworkDetailsMetadataSection(
                            context, assetToken, artistName),
                        if (ownerItems?.isNotEmpty ?? false) ...[
                          tokenOwnership(
                            context,
                            assetToken,
                            identityState.identityMap[assetToken
                                        .owners?.items.first.ownerAddress ??
                                    ''] ??
                                '',
                          ),
                        ],
                        if (state.assetToken?.provenance.isNotEmpty ?? false)
                          _provenanceView(
                              context, state.assetToken?.provenance ?? [])
                        else
                          const SizedBox(),
                        artworkDetailsRightSection(context, assetToken),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: (MediaQuery.of(context).size.height -
                            (_appBarBottomDy ?? 80) -
                            _infoHeaderHeight) *
                        0.5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _provenanceView(
          BuildContext context, List<ProvenanceEvent> provenances) =>
      BlocBuilder<IdentityBloc, IdentityState>(
        builder: (context, identityState) =>
            BlocBuilder<AccountsBloc, AccountsState>(
          builder: (context, accountsState) {
            final addresses = accountsState.addresses?.map((e) => e.address);
            if (addresses?.isNotEmpty == true) {
              _accountNumberHash = HashSet.of(addresses!);
            }

            return artworkDetailsProvenanceSectionNotEmpty(
              context,
              provenances,
              _accountNumberHash,
              identityState.identityMap,
            );
          },
        ),
      );

  Future<void> _showArtworkOptionsDialog(
    BuildContext context,
    AssetToken asset,
    CanvasDeviceState canvasDeviceState,
  ) async {
    if (!context.mounted) {
      return;
    }
    _focusNode.unfocus();

    final isPlaying = canvasDeviceState.isAssetPlayingOnFF1(asset);

    unawaited(
      UIHelper.showCenterMenu(
        context,
        options: [
          OptionItem(
            title: 'full_screen'.tr(),
            icon: SvgPicture.asset(
              'assets/images/fullscreen_icon.svg',
              width: 18,
              height: 18,
            ),
            onTap: () {
              Navigator.of(context).pop();
              _setFullScreen();
            },
          ),
          if (isPlaying)
            OptionItem(
              title: 'interact'.tr(),
              icon: SvgPicture.asset(
                'assets/images/keyboard_icon.svg',
                width: 22,
                height: 14.68,
              ),
              onTap: () {
                Navigator.of(context).pop();
                final bluetoothConnectedDevice =
                    BluetoothDeviceManager().castingBluetoothDevice;
                if (bluetoothConnectedDevice != null &&
                    canvasDeviceState.isAssetPlayingOnFF1(asset)) {
                  unawaited(
                    Navigator.of(context).pushNamed(
                      AppRouter.keyboardControlPage,
                      arguments: KeyboardControlPagePayload(
                        '',
                        asset.displayDescription,
                        [bluetoothConnectedDevice],
                      ),
                    ),
                  );
                } else {
                  FocusScope.of(context).requestFocus(_focusNode);
                }
              },
            ),
          if (asset.secondaryMarketURL.isNotEmpty)
            OptionItem(
              title: 'view_on_'.tr(args: [asset.secondaryMarketName]),
              icon: SvgPicture.asset(
                'assets/images/external_link_white.svg',
                width: 20,
                height: 20,
              ),
              onTap: () async {
                final browser = FeralFileBrowser();
                await browser.openUrl(asset.secondaryMarketURL);
              },
            ),
          OptionItem(
            title: 'Artwork details',
            icon: SvgPicture.asset(
              'assets/images/info_white.svg',
              width: 22,
              height: 22,
            ),
            onTap: () {
              Navigator.of(context).pop();
              _infoExpand();
            },
          ),
          OptionItem(
            title: 'rebuild_metadata'.tr(),
            icon: SvgPicture.asset(
              'assets/images/refresh_metadata_white.svg',
              width: 20,
              height: 20,
            ),
            onTap: () async {
              try {
                // Trigger reindex by CID and wait until the workflow is done
                await injector<NftTokensService>().reindexByCidsAndPullStatus(
                  tokenCids: [asset.cid],
                  timeout: const Duration(minutes: 3),
                  onStatus: (status, workflowId, runId) async {
                    // complete when workflow finishes
                    if (status.isDone && !status.isSuccess) {
                      Sentry.captureEvent(SentryEvent(
                        message: SentryMessage(
                            'Rebuild metadata failed for cid: ${asset.cid}'),
                        level: SentryLevel.error,
                        extra: {
                          'status': status.toString(),
                          'workflowId': workflowId,
                          'runId': runId,
                        },
                      ));
                    }
                    return status.isDone;
                  },
                  onTimeout: () async {
                    Sentry.captureEvent(SentryEvent(
                      message: SentryMessage(
                          'Rebuild metadata timeout for cid: ${asset.cid}'),
                      level: SentryLevel.error,
                    ));
                    // No-op; we still proceed to fetch what we can
                  },
                  onError: (error, stackTrace) async {
                    // No-op; allow flow to continue to fetch and reload
                    Sentry.captureEvent(SentryEvent(
                      message: SentryMessage(
                          'Rebuild metadata error for cid: ${asset.cid}'),
                      level: SentryLevel.error,
                      extra: {
                        'error': error.toString(),
                        'stackTrace': stackTrace.toString(),
                      },
                    ));
                  },
                );
                // Fetch the latest token and persist to database
                await injector<NftTokensService>()
                    .getManualTokens(cids: [asset.cid]);
              } catch (_) {
                // Ignore errors and continue to reload UI
              }
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              // Reload current artwork state without navigation
              _bloc.add(
                ArtworkDetailGetInfoEvent(
                  widget.payload.identity,
                  useIndexer: widget.payload.useIndexer,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _setFullScreen() async {
    unawaited(_openSnackBar(context));
    if (_isInfoExpand) {
      _infoShrink();
    }
    // Save previous bottomSheetVisibility state
    _previousBottomSheetVisibility =
        CustomRouteObserver.bottomSheetVisibility.value;
    CustomRouteObserver.bottomSheetVisibility.value = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await enableLandscapeMode();
    unawaited(WakelockPlus.enable());
    setState(() {
      shouldShowNowDisplaying.value = false;
      _isFullScreen = true;
    });
  }

  Future<void> _exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    unawaited(WakelockPlus.disable());
    await disableLandscapeMode();
    // Restore bottomSheetVisibility to its previous state
    CustomRouteObserver.bottomSheetVisibility.value =
        _previousBottomSheetVisibility;
    setState(() {
      shouldShowNowDisplaying.value = true;
      _isFullScreen = false;
    });
  }

  Future<void> _openSnackBar(BuildContext context) async {
    await UIHelper.openSnackBarExistFullScreen(context);
  }
}

class ArtworkBackLayer extends StatelessWidget {
  const ArtworkBackLayer({
    required this.assetToken,
    required this.canvasDeviceBloc,
    required this.useIndexer,
    required this.identity,
    required this.onLoaded,
    required this.isFullScreen,
    super.key,
  });

  final AssetToken assetToken;
  final CanvasDeviceBloc canvasDeviceBloc;
  final bool useIndexer;
  final ArtworkIdentity identity;
  final dynamic Function({WebViewController? webViewController, int? time})
      onLoaded;
  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CanvasDeviceBloc, CanvasDeviceState, bool>(
      bloc: canvasDeviceBloc,
      selector: (canvasState) => canvasState.isAssetPlayingOnFF1(assetToken),
      builder: (context, isPlayingOnFF1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: UIConstants.detailPageHeaderPadding,
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: isPlayingOnFF1
                          ? ArtworkThumbnailView(assetToken: assetToken)
                          : ArtworkPreviewWidget(
                              useIndexer: useIndexer,
                              identity: identity,
                              onLoaded: onLoaded,
                            ),
                    ),
                  ),
                  if (isPlayingOnFF1)
                    Center(
                      child: ArtworkPlayingControls(
                        playingDevice:
                            BluetoothDeviceManager().castingBluetoothDevice!,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
              height: UIConstants.detailPageHeaderPadding,
            ),
            if (!isFullScreen)
              const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: ArtworkDetailsHeader(
                      title: 'I',
                      subTitle: 'I',
                      color: Colors.transparent,
                    ),
                  ),
                  BottomSpacing(),
                ],
              ),
          ],
        );
      },
    );
  }
}

class ArtworkThumbnailView extends StatelessWidget {
  const ArtworkThumbnailView({required this.assetToken, super.key});

  final AssetToken assetToken;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = assetToken.getGalleryThumbnailUrl();
    return Opacity(
      opacity: 0.5,
      child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          ? FFArtworkThumbnailView(
              url: thumbnailUrl,
            )
          : const GalleryNoThumbnailWidget(),
    );
  }
}

class ArtworkDetailPayload {
  ArtworkDetailPayload(
    this.identity, {
    this.useIndexer = true,
    this.key,
    this.backTitle,
  });

  final Key? key;
  final ArtworkIdentity identity;
  final bool useIndexer; // set true when navigate from discover/gallery page
  // if local token, it can be hidden and refresh metadata
  final String? backTitle;

  ArtworkDetailPayload copyWith({
    ArtworkIdentity? identity,
    bool? useIndexer,
  }) =>
      ArtworkDetailPayload(
        identity ?? this.identity,
        useIndexer: useIndexer ?? this.useIndexer,
      );
}

class ArtworkIdentity {
  ArtworkIdentity(this.cid);

  final String cid;

  String get key => cid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ArtworkIdentity && cid == other.cid;
  }

  @override
  int get hashCode => cid.hashCode;
}
