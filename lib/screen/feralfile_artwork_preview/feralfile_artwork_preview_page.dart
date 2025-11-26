import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/nft_rendering/webview_controller_ext.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/feralfile_artwork_details/feralfile_artwork_details_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/metric_client_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/metric_helper.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/artwork_title_view.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/feralfile_artwork_preview_widget.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/webview_controller_text_field.dart';
import 'package:backdrop/backdrop.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:sentry/sentry.dart';
import 'package:shake/shake.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FeralFileArtworkPreviewPage extends StatefulWidget {
  const FeralFileArtworkPreviewPage({required this.payload, super.key});

  final FeralFileArtworkPreviewPagePayload payload;

  @override
  State<FeralFileArtworkPreviewPage> createState() =>
      _FeralFileArtworkPreviewPageState();
}

class _FeralFileArtworkPreviewPageState
    extends State<FeralFileArtworkPreviewPage>
    with
        AfterLayoutMixin<FeralFileArtworkPreviewPage>,
        SingleTickerProviderStateMixin {
  final _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
  double? _appBarBottomDy;
  static const _infoShrinkPosition = 0.001;
  static const _infoExpandPosition = 0.99;
  static const toolbarHeight = 66.0;
  bool _isInfoExpand = false;
  bool _isFullScreen = false;
  ShakeDetector? _detector;

  final _focusNode = FocusNode();
  final _textController = TextEditingController();
  WebViewController? _webViewController;

  ScrollController? _scrollController;
  late AnimationController _animationController;

  final _feralfileArtworkDetailsBloc = FeralfileArtworkDetailsBloc(injector());

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
      value: _infoShrinkPosition,
      upperBound: _infoExpandPosition,
    );
    _infoShrink();
    super.initState();
    _feralfileArtworkDetailsBloc.add(
      FeralfileArtworkDetailsLoadEvent(widget.payload.artworkId),
    );
  }

  void _sendMetricViewExhibition(Artwork artwork) {
    final exhibitionId = artwork.series?.exhibitionID;
    final data = {
      MetricParameter.exhibitionId: exhibitionId,
      MetricParameter.section: ExhibitionCatalog.artwork.metricName,
      MetricParameter.tokenId: artwork.id,
    };

    injector<MetricClientService>()
        .addEvent(MetricEventName.exhibitionView, data: data);
  }

  @override
  void didUpdateWidget(covariant FeralFileArtworkPreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _appBarBottomDy ??= MediaQuery.of(context).padding.top + kToolbarHeight;
    _detector = ShakeDetector.autoStart(
      onPhoneShake: (event) async {
        await _exitFullScreen();
      },
    );
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    _animationController.dispose();
    _focusNode.dispose();
    _webViewController?.onDispose();
    _detector?.stopListening();
    unawaited(SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    ));
    unawaited(disableLandscapeMode());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
          bloc: _canvasDeviceBloc,
          builder: (context, canvasState) {
            final theme = Theme.of(context);
            return BlocBuilder<FeralfileArtworkDetailsBloc,
                FeralfileArtworkDetailsState>(
              bloc: _feralfileArtworkDetailsBloc,
              buildWhen: (previous, current) {
                // Only rebuild when the artwork is loaded or an error occurs
                if (current is FeralfileArtworkDetailsLoadedState) {
                  final artwork = current.artwork;
                  _sendMetricViewExhibition(artwork!);
                }
                return true;
              },
              builder: (context, artworkDetailState) {
                if (artworkDetailState is FeralfileArtworkDetailsErrorState) {
                  return Center(
                    child: Text(artworkDetailState.error,
                        style: theme.textTheme.ppMori400White14),
                  );
                }
                if (artworkDetailState is FeralfileArtworkDetailsLoadedState) {
                  final artwork = artworkDetailState.artwork!;
                  return _buildBackdrop(
                    context,
                    artwork,
                    canvasState,
                  );
                }
                if (artworkDetailState is FeralfileArtworkDetailsLoadingState) {
                  return const Center(child: LoadingWidget());
                }
                return const Center(child: LoadingWidget());
              },
            );
          });

  Widget _buildBackdrop(
      BuildContext context, Artwork artwork, CanvasDeviceState canvasState) {
    return BackdropScaffold(
      appBar: _isFullScreen
          ? null
          : _isInfoExpand
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(toolbarHeight),
                  child: SizedBox(
                    height: toolbarHeight,
                  ),
                )
              : getFFAppBar(context,
                  onBack: () => Navigator.pop(context),
                  action: FFCastButton(
                    displayKey: artwork.series?.exhibitionID ?? '',
                    onDeviceSelected: (BaseDevice device) =>
                        _onDeviceSelected(device, artwork),
                  )),
      backgroundColor: AppColor.primaryBlack,
      frontLayerElevation: _isFullScreen ? 0 : 1,
      frontLayerBackgroundColor:
          _isFullScreen ? Colors.transparent : AppColor.primaryBlack,
      backLayerBackgroundColor: AppColor.primaryBlack,
      frontLayerScrim: Colors.transparent,
      backLayerScrim: Colors.transparent,
      reverseAnimationCurve: Curves.ease,
      animationController: _animationController,
      revealBackLayerAtStart: true,
      subHeaderAlwaysActive: false,
      frontLayerShape: const BeveledRectangleBorder(),
      backLayer: Column(
        children: [
          Expanded(
            child: _buildArtworkPreview(artwork),
          ),
          if (!_isFullScreen) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: ArtworkDetailsHeader(
                title: 'I',
                subTitle: 'I',
                color: Colors.transparent,
              ),
            ),
            if (artwork.isCrystallineWork) ...[
              const SizedBox(height: 20),
              ArtworkAttributesText(
                artwork: artwork,
                color: Colors.transparent,
              ),
            ]
          ]
        ],
      ),
      frontLayer:
          _isFullScreen ? const SizedBox() : _infoContent(context, artwork),
      subHeader: _isFullScreen
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(color: AppColor.primaryBlack),
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
                  color: Colors.transparent,
                  child: _infoHeader(context, artwork, canvasState),
                ),
              ),
            ),
    );
  }

  Widget _buildArtworkPreview(Artwork artwork) => FeralfileArtworkPreviewWidget(
        payload: FeralFileArtworkPreviewWidgetPayload(
          artwork: artwork,
          onLoaded: _onLoaded,
          isMute: false,
          isScrollable: artwork.isScrollablePreviewURL,
        ),
      );

  Future<void> _onDeviceSelected(BaseDevice device, Artwork artwork) async {
    final exhibitionId = artwork.series?.exhibitionID;
    if (exhibitionId == null) {
      await Sentry.captureMessage('Exhibition ID is null for artwork '
          '${artwork.id}');
    } else {
      final artworkId = artwork.id;
      final request = CastExhibitionRequest(
        exhibitionId: exhibitionId,
        catalog: ExhibitionCatalog.artwork,
        catalogId: artworkId,
      );
      final completer = Completer<void>();
      _canvasDeviceBloc.add(
        CanvasDeviceCastExhibitionEvent(
          device,
          request,
          onDone: () {
            completer.complete();
          },
        ),
      );
      await completer.future;
    }
  }

  dynamic _onLoaded({WebViewController? webViewController, int? time}) {
    _webViewController = webViewController;
  }

  void _infoShrink() {
    setState(() {
      _isInfoExpand = false;
    });
    _animationController.animateTo(_infoShrinkPosition);
  }

  void _infoExpand() {
    _scrollController?.jumpTo(0);
    if (_scrollController == null) {
      _initScrollController();
    }
    setState(() {
      _isInfoExpand = true;
    });
    _animationController.animateTo(_infoExpandPosition);
  }

  void _initScrollController() {
    _scrollController = ScrollController();
    _scrollController!.addListener(() {
      if (_scrollController!.position.pixels < -20 && _isInfoExpand) {
        _infoShrink();
      }
    });
  }

  Widget _artworkInfoIcon() => Semantics(
        label: 'artworkInfoIcon',
        child: IconButton(
            onPressed: () {
              _isInfoExpand ? _infoShrink() : _infoExpand();
            },
            constraints: const BoxConstraints(
              maxWidth: 44,
              maxHeight: 44,
              minWidth: 44,
              minHeight: 44,
            ),
            icon: SvgPicture.asset(
              !_isInfoExpand
                  ? 'assets/images/info_white.svg'
                  : 'assets/images/info_white_active.svg',
              width: 22,
              height: 22,
            )),
      );

  Widget _infoHeader(BuildContext context, Artwork artwork,
          CanvasDeviceState canvasState) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(15, 15, 5, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ArtworkTitleView(
                    artwork: artwork,
                  ),
                ),
                _artworkInfoIcon(),
                Semantics(
                  label: 'artworkDotIcon',
                  child: IconButton(
                    onPressed: () async => _showArtworkOptionsDialog(
                        context, artwork, canvasState),
                    icon: SvgPicture.asset(
                      'assets/images/more_circle.svg',
                      width: 22,
                    ),
                  ),
                ),
              ],
            ),
            if (artwork.isCrystallineWork) ...[
              const SizedBox(height: 20),
              ArtworkAttributesText(
                artwork: artwork,
              ),
            ]
          ],
        ),
      );

  Future<void> _showArtworkOptionsDialog(BuildContext context, Artwork artwork,
      CanvasDeviceState canvasDeviceState) async {
    final castingDevice = canvasDeviceState
        .lastSelectedActiveDeviceForKey(artwork.series?.exhibitionID ?? '');
    final status =
        canvasDeviceState.canvasDeviceStatus[castingDevice?.deviceId];
    final isCastingThisArtwork =
        castingDevice != null && status?.catalogId == artwork.id;
    if (!context.mounted) {
      return;
    }
    final artistAddresses = artwork.series?.artistAlumni?.addressesList;
    final isUserArtist = artistAddresses == null
        ? false
        : injector<AuthService>().isLinkArtist(artistAddresses);
    _focusNode.unfocus();
    unawaited(UIHelper.showDrawerAction(
      context,
      options: [
        OptionItem(
            title: 'full_screen'.tr(),
            icon: SvgPicture.asset('assets/images/fullscreen_icon.svg'),
            onTap: () {
              Navigator.of(context).pop();
              _setFullScreen();
            }),
        if (isUserArtist)
          OptionItem(
            title: 'Artist Display Settings',
            icon: const Icon(
              AuIcon.settings,
              color: AppColor.white,
            ),
            onTap: () {
              injector<NavigationService>().openArtistDisplaySetting(
                artwork: artwork,
              );
            },
          ),
        if (isCastingThisArtwork)
          OptionItem(
            title: 'interact'.tr(),
            icon: SvgPicture.asset('assets/images/keyboard_icon.svg'),
            onTap: () {
              Navigator.of(context).pop();
              if (isCastingThisArtwork) {
                unawaited(Navigator.of(context).pushNamed(
                  AppRouter.keyboardControlPage,
                  arguments: KeyboardControlPagePayload(
                    artwork.name,
                    '',
                    [castingDevice],
                  ),
                ));
              } else {
                FocusScope.of(context).requestFocus(_focusNode);
              }
            },
          ),
        OptionItem.emptyOptionItem,
      ],
    ));
  }

  Future<void> _setFullScreen() async {
    unawaited(_openSnackBar(context));
    if (_isInfoExpand) {
      _infoShrink();
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await enableLandscapeMode();
    unawaited(WakelockPlus.enable());
    setState(() {
      _isFullScreen = true;
    });
  }

  Future<void> _exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await disableLandscapeMode();
    unawaited(WakelockPlus.disable());
    setState(() {
      _isFullScreen = false;
    });
  }

  Future<void> _openSnackBar(BuildContext context) async {
    await UIHelper.openSnackBarExistFullScreen(context);
  }

  Widget _infoContent(BuildContext context, Artwork artwork) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Visibility(
            child: WebviewControllerTextField(
          webViewController: _webViewController,
          focusNode: _focusNode,
          textController: _textController,
          disableKeys: artwork.series?.exhibition?.disableKeys ?? [],
        )),
        SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics()
              .applyTo(const AlwaysScrollableScrollPhysics()),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Visibility(
                  visible: artwork.series!.mediumDescription != null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: ResponsiveLayout.getPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artwork.series!.mediumDescription ?? '',
                            style: theme.textTheme.ppMori400White14,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
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
                        child: HtmlWidget(
                          customStylesBuilder: auHtmlStyle,
                          artwork.series!.description ?? '',
                          textStyle: theme.textTheme.ppMori400White14,
                          onTapUrl: (url) async {
                            await launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication);
                            return true;
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                      FFArtworkDetailsMetadataSection(artwork: artwork),
                      if (artwork.series?.exhibition != null)
                        ArtworkRightsView(
                          contractAddress: artwork
                              .getContract(artwork.series!.exhibition)
                              ?.address,
                          artworkID: artwork.id,
                          exhibitionID: artwork.series!.exhibitionID,
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FeralFileArtworkPreviewPagePayload {
  final String artworkId;
  bool isFromExhibition;

  FeralFileArtworkPreviewPagePayload({
    required this.artworkId,
    this.isFromExhibition = false,
  });
}
