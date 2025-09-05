import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/nft_rendering/svg_image.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/royalty/royalty_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/metric_client_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/color_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/datetime_ext.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/image_ext.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

String getEditionSubTitle(AssetToken token) {
  if (token.editionName != null && token.editionName != '') {
    return token.editionName!;
  }
  if (token.edition == 0) {
    return '';
  }
  return token.maxEdition != null && token.maxEdition! >= 1
      ? tr(
          'edition_of',
          args: [token.edition.toString(), token.maxEdition.toString()],
        )
      : '${tr('edition')} ${token.edition}';
}

class MintTokenWidget extends StatelessWidget {
  const MintTokenWidget({super.key, this.thumbnail, this.tokenId});

  final String? thumbnail;
  final String? tokenId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'gallery_artwork_${tokenId}_minting',
      child: Container(
        color: theme.auLightGrey,
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Center(child: SvgPicture.asset('assets/images/mint_icon.svg')),
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Text(
                'minting_token'.tr(),
                style: theme.textTheme.ppMori700QuickSilver8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingTokenWidget extends StatelessWidget {
  const PendingTokenWidget({
    super.key,
    this.thumbnail,
    this.tokenId,
    this.shouldRefreshCache = false,
  });

  final String? thumbnail;
  final String? tokenId;
  final bool shouldRefreshCache;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'gallery_artwork_${tokenId}_pending',
      child: Container(
        color: theme.auLightGrey,
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            if (thumbnail?.isNotEmpty == true) ...[
              SizedBox.expand(
                child: ImageExt.customNetwork(
                  thumbnail!,
                  fit: BoxFit.cover,
                  shouldRefreshCache: shouldRefreshCache,
                ),
              ),
            ] else ...[
              Center(
                child: loadingIndicator(
                  size: 22,
                  strokeWidth: 1.5,
                  valueColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ],
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Text(
                'pending_token'.tr(),
                style: theme.textTheme.ppMori700QuickSilver8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final Map<String, Future<bool>> _cachingStates = {};

Widget tokenGalleryThumbnailWidget(
  BuildContext context,
  CompactedAssetToken token,
  int cachedImageSize, {
  bool usingThumbnailID = true,
  String variant = 'thumbnail',
  double ratio = 1,
  bool useHero = true,
  Widget? galleryThumbnailPlaceholder,
}) {
  ///hardcode for JG
  final isJohnGerrard = token.isJohnGerrardArtwork;
  final thumbnailUrl = token.getGalleryThumbnailUrl(
    usingThumbnailID: usingThumbnailID && !isJohnGerrard,
    variant: variant,
  );

  if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
    return GalleryNoThumbnailWidget(
      assetToken: token,
    );
  }

  final cacheManager = injector<CacheManager>();

  final cachingState = _cachingStates[thumbnailUrl] ??
      // ignore: discarded_futures
      cacheManager.store.retrieveCacheData(thumbnailUrl).then((cachedObject) {
        final isCached = cachedObject != null;
        if (isCached) {
          _cachingStates[thumbnailUrl] = Future.value(true);
        }
        return isCached;
      });
  final memCacheWidth = cachedImageSize;
  final memCacheHeight = memCacheWidth ~/ ratio;

  final ext = p.extension(thumbnailUrl);
  final shouldRefreshCache = token.shouldRefreshThumbnailCache;
  return Semantics(
    label: 'gallery_artwork_${token.id}',
    child: Hero(
      tag: useHero
          ? 'gallery_thumbnail_${token.id}_${token.owner}'
          : const Uuid().v4(),
      key: const Key('Artwork_Thumbnail'),
      child: ext == '.svg'
          ? SvgImage(
              url: thumbnailUrl,
              loadingWidgetBuilder: (_) => const GalleryThumbnailPlaceholder(),
              errorWidgetBuilder: (_) => const GalleryThumbnailErrorWidget(),
              unsupportWidgetBuilder: (context) =>
                  const GalleryUnSupportThumbnailWidget(),
            )
          : ImageExt.customNetwork(
              thumbnailUrl,
              fadeInDuration: Duration.zero,
              fit: BoxFit.cover,
              memCacheHeight: memCacheHeight,
              memCacheWidth: memCacheWidth,
              maxWidthDiskCache: cachedImageSize,
              maxHeightDiskCache: cachedImageSize,
              cacheManager: cacheManager,
              placeholder: (context, index) => FutureBuilder<bool>(
                future: cachingState,
                builder: (context, snapshot) =>
                    galleryThumbnailPlaceholder ??
                    GalleryThumbnailPlaceholder(
                      loading: !(snapshot.data ?? true),
                    ),
              ),
              errorWidget: (context, url, error) {
                return ImageExt.customNetwork(
                  token.getGalleryThumbnailUrl(usingThumbnailID: false) ?? '',
                  fadeInDuration: Duration.zero,
                  fit: BoxFit.cover,
                  memCacheHeight: cachedImageSize,
                  memCacheWidth: cachedImageSize,
                  maxWidthDiskCache: cachedImageSize,
                  maxHeightDiskCache: cachedImageSize,
                  cacheManager: cacheManager,
                  placeholder: (context, index) => FutureBuilder<bool>(
                    future: cachingState,
                    builder: (context, snapshot) =>
                        galleryThumbnailPlaceholder ??
                        GalleryThumbnailPlaceholder(
                          loading: !(snapshot.data ?? true),
                        ),
                  ),
                  errorWidget: (context, url, error) =>
                      const GalleryThumbnailErrorWidget(),
                );
              },
              shouldRefreshCache: shouldRefreshCache,
            ),
    ),
  );
}

class GalleryUnSupportThumbnailWidget extends StatelessWidget {
  const GalleryUnSupportThumbnailWidget({super.key, this.type = '.svg'});

  final String type;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    return Container(
      width: size.width,
      height: size.width,
      padding: const EdgeInsets.all(10),
      color: theme.auLightGrey,
      child: Stack(
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/unsupported_token.svg',
              width: 24,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Text(
              'unsupported_token'.tr(),
              style: theme.textTheme.ppMori700QuickSilver8,
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryThumbnailErrorWidget extends StatelessWidget {
  const GalleryThumbnailErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      color: theme.auLightGrey,
      child: Stack(
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/ipfs_error_icon.svg',
              width: 24,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Text(
              'IPFS_error'.tr(),
              style: theme.textTheme.ppMori700QuickSilver8,
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryNoThumbnailWidget extends StatelessWidget {
  const GalleryNoThumbnailWidget({required this.assetToken, super.key});

  final CompactedAssetToken assetToken;

  String getAssetDefault() {
    switch (assetToken.getMimeType) {
      case RenderingType.modelViewer:
        return 'assets/images/icon_3d.svg';
      case RenderingType.webview:
        return 'assets/images/icon_software.svg';
      case RenderingType.video:
        return 'assets/images/icon_video.svg';
      default:
        return 'assets/images/no_thumbnail.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    return Container(
      height: size.width,
      width: size.width,
      padding: const EdgeInsets.all(10),
      color: theme.auLightGrey,
      child: Stack(
        children: [
          Center(
            child: SvgPicture.asset(
              getAssetDefault(),
              width: 24,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Text(
              'no_thumbnail'.tr(),
              style: theme.textTheme.ppMori700QuickSilver8,
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryThumbnailPlaceholder extends StatelessWidget {
  const GalleryThumbnailPlaceholder({
    super.key,
    this.loading = true,
  });

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: loading ? 'loading' : '',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: theme.auLightGrey,
          child: Stack(
            children: [
              Visibility(
                visible: loading,
                child: Center(
                  child: loadingIndicator(
                    size: 22,
                    strokeWidth: 1.5,
                    valueColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                ),
              ),
              Visibility(
                visible: loading,
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Text(
                    'loading'.tr(),
                    style: theme.textTheme.ppMori700QuickSilver8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget placeholder(BuildContext context) => const LoadingWidget();

class RetryCubit extends Cubit<int> {
  RetryCubit() : super(0);

  void refresh() {
    emit(state + 1);
  }
}

class BrokenTokenWidget extends StatefulWidget {
  const BrokenTokenWidget({required this.token, super.key});

  final AssetToken token;

  @override
  State<StatefulWidget> createState() => _BrokenTokenWidgetState();
}

class _BrokenTokenWidgetState extends State<BrokenTokenWidget>
    with AfterLayoutMixin<BrokenTokenWidget> {
  final metricClient = injector.get<MetricClientService>();

  @override
  void afterFirstLayout(BuildContext context) {}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.width,
      padding: const EdgeInsets.all(10),
      color: AppColor.auGreyBackground,
      child: Stack(
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/ipfs_error_icon.svg',
              width: 40,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Row(
              children: [
                Text(
                  'unable_to_load_artwork_preview_from_ipfs'.tr(),
                  style: theme.textTheme.ppMori700QuickSilver8
                      .copyWith(fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    context.read<RetryCubit>().refresh();
                  },
                  child: Text(
                    'reload'.tr(),
                    style: theme.textTheme.ppMori400Black12
                        .copyWith(color: AppColor.feralFileHighlight),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget previewPlaceholder() => const PreviewPlaceholder();

class PreviewPlaceholder extends StatefulWidget {
  const PreviewPlaceholder({
    super.key,
  });

  @override
  State<PreviewPlaceholder> createState() => _PreviewPlaceholderState();
}

class _PreviewPlaceholderState extends State<PreviewPlaceholder> {
  @override
  Widget build(BuildContext context) => const LoadingWidget();
}

Widget debugInfoWidget(BuildContext context, AssetToken? token) {
  final theme = Theme.of(context);

  if (token == null) {
    return const SizedBox();
  }

  return FutureBuilder<bool>(
    // ignore: discarded_futures
    future: isAppCenterBuild().then((value) {
      if (!value) {
        return Future.value(false);
      }

      return injector<ConfigurationService>().showTokenDebugInfo();
    }),
    builder: (context, snapshot) {
      if (snapshot.data == false) {
        return const SizedBox();
      }

      TextButton buildInfo(String text, String value) => TextButton(
            onPressed: () async {
              // Vibrate.feedback(FeedbackType.light);
              final uri = Uri.tryParse(value);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.inAppWebView);
              } else {
                await Clipboard.setData(ClipboardData(text: value));
              }
            },
            child: Text(
              '$text:  $value',
              style: theme.textTheme.ppMori400White12,
            ),
          );

      return Column(
        children: [
          addDivider(),
          Text(
            'debug_info'.tr(),
            style: theme.textTheme.ppMori400White12,
          ),
          buildInfo('IndexerID', token.id),
          buildInfo(
            'galleryThumbnailURL',
            token.getGalleryThumbnailUrl() ?? '',
          ),
          buildInfo('previewURL', token.getPreviewUrl() ?? ''),
          addDivider(),
        ],
      );
    },
  );
}

Widget artworkDetailsRightSection(BuildContext context, AssetToken assetToken) {
  final artworkID = assetToken.feralfileArtworkId;
  if (assetToken.shouldShowFeralfileRight) {
    return ArtworkRightsView(
      contractAddress: assetToken.contractAddress,
      artworkID: artworkID,
    );
  }
  return const SizedBox();
}

class ListItemExpandedWidget extends StatefulWidget {
  const ListItemExpandedWidget({
    required this.children,
    required this.unexpandedCount,
    required this.expandWidget,
    required this.unexpandWidget,
    super.key,
    this.divider,
  });

  final List<Widget> children;
  final TextSpan? divider;
  final int unexpandedCount;
  final Widget expandWidget;
  final Widget unexpandWidget;

  @override
  State<ListItemExpandedWidget> createState() => _ListItemExpandedWidgetState();
}

class _ListItemExpandedWidgetState extends State<ListItemExpandedWidget> {
  bool _isExpanded = false;

  Widget unexpanedWidget(BuildContext context) {
    final expandText = (widget.children.length - widget.unexpandedCount > 0)
        ? GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = true;
              });
            },
            child: widget.expandWidget,
          )
        : const SizedBox();
    final subList = widget.children
        .sublist(0, min(widget.unexpandedCount, widget.children.length));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...subList,
        expandText,
      ],
    );
  }

  Widget expanedWidget(BuildContext context) {
    final expandText = GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = false;
        });
      },
      child: widget.unexpandWidget,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.children,
        const SizedBox(height: 10),
        expandText,
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      _isExpanded ? expanedWidget(context) : unexpanedWidget(context);
}

class SectionExpandedWidget extends StatefulWidget {
  const SectionExpandedWidget({
    super.key,
    this.header,
    this.headerStyle,
    this.headerPadding,
    this.child,
    this.iconOnExpanded,
    this.iconOnUnExpanded,
    this.withDivider = true,
    this.padding = EdgeInsets.zero,
  });

  final String? header;
  final TextStyle? headerStyle;
  final EdgeInsets? headerPadding;
  final Widget? child;
  final Widget? iconOnExpanded;
  final Widget? iconOnUnExpanded;
  final bool withDivider;
  final EdgeInsets padding;

  @override
  State<SectionExpandedWidget> createState() => _SectionExpandedWidgetState();
}

class _SectionExpandedWidgetState extends State<SectionExpandedWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultIcon = Icon(
      AuIcon.chevron_Sm,
      size: 12,
      color: theme.colorScheme.secondary,
    );
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.withDivider) artworkSectionDivider,
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Padding(
                    padding: widget.headerPadding ?? EdgeInsets.zero,
                    child: Row(
                      children: [
                        Text(
                          widget.header ?? '',
                          style: widget.headerStyle ??
                              theme.textTheme.ppMori400White14,
                        ),
                        const Spacer(),
                        if (_isExpanded)
                          widget.iconOnExpanded ??
                              RotatedBox(
                                quarterTurns: 1,
                                child: defaultIcon,
                              )
                        else
                          widget.iconOnUnExpanded ??
                              RotatedBox(
                                quarterTurns: 2,
                                child: defaultIcon,
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Visibility(
            visible: _isExpanded,
            child: Column(
              children: [
                const SizedBox(height: 23),
                widget.child ?? const SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArtworkAttributesText extends StatelessWidget {
  const ArtworkAttributesText({required this.artwork, super.key, this.color});

  final Artwork artwork;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      artwork.attributesString ?? '',
      style: theme.textTheme.ppMori400FFQuickSilver12.copyWith(
        color: color ?? AppColor.feralFileMediumGrey,
      ),
    );
  }
}

class FFArtworkDetailsMetadataSection extends StatelessWidget {
  const FFArtworkDetailsMetadataSection({required this.artwork, super.key});

  final Artwork artwork;

  @override
  Widget build(BuildContext context) {
    const divider = artworkDataDivider;
    final contract = artwork.getContract(artwork.series!.exhibition);
    return SectionExpandedWidget(
      header: 'metadata'.tr(),
      padding: const EdgeInsets.only(bottom: 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetaDataItem(
            title: 'title'.tr(),
            value: artwork.series!.displayTitle,
          ),
          if (artwork.series!.artistAlumni?.alias != null) ...[
            divider,
            MetaDataItem(
              title: 'artist'.tr(),
              value: artwork.series!.artistAlumni!.displayAlias,
              onTap: () async {
                if (artwork.series!.artistAlumni!.slug != null) {
                  await injector<NavigationService>().openFeralFileArtistPage(
                    artwork.series!.artistAlumni!.slug!,
                  );
                }
              },
            ),
          ],
          divider,
          MetaDataItem(
            title: 'edition'.tr(),
            value: artwork.name,
          ),
          divider,
          MetaDataItem(
            title: 'token'.tr(),
            value: polishSource('feralfile'),
            tapLink: feralFileArtworkUrl(artwork.id),
            forceSafariVC: true,
          ),
          if (artwork.series!.exhibition != null) ...[
            divider,
            MetaDataItem(
              title: 'exhibition'.tr(),
              value: artwork.series!.exhibition!.title,
              onTap: () {
                unawaited(
                  Navigator.of(context).pushNamed(
                    AppRouter.exhibitionDetailPage,
                    arguments: ExhibitionDetailPayload(
                      exhibitions: [artwork.series!.exhibition!],
                      index: 0,
                    ),
                  ),
                );
              },
            ),
          ],
          divider,
          MetaDataItem(
            title: 'medium'.tr(),
            value: artwork.series!.medium.capitalize(),
          ),
          if (contract != null) ...[
            divider,
            MetaDataItem(
              title: 'contract'.tr(),
              value: contract.blockchainType.capitalize(),
              tapLink: contract.getBlockchainUrl(),
              forceSafariVC: true,
            ),
          ],
          if (artwork.mintedAt != null) ...[
            divider,
            MetaDataItem(
              title: 'date_minted'.tr(),
              value: localTimeString(artwork.mintedAt!),
            ),
          ],
          const SizedBox(
            height: 32,
          ),
        ],
      ),
    );
  }
}

Widget artworkDetailsMetadataSection(
  BuildContext context,
  AssetToken assetToken,
  String? artistName,
) {
  final artworkID =
      ((assetToken.swapped ?? false) && assetToken.originTokenInfoId != null)
          ? assetToken.originTokenInfoId ?? ''
          : assetToken.id.split('-').last;
  const divider = artworkDataDivider;
  return SectionExpandedWidget(
    header: 'metadata'.tr(),
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaDataItem(
          title: 'title'.tr(),
          value: assetToken.displayTitle ?? '',
        ),
        if (artistName != null) ...[
          divider,
          MetaDataItem(
            title: 'artist'.tr(),
            value: artistName,
            onTap: () async {
              if (!assetToken.isFeralfile) {
                final uri = Uri.parse(
                  assetToken.artistURL?.split(' & ').firstOrNull ?? '',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                unawaited(
                  injector<NavigationService>()
                      .openFeralFileArtistPage(assetToken.artistID!),
                );
              }
            },
            forceSafariVC: true,
          ),
        ],
        if (!assetToken.fungible)
          Column(
            children: [
              divider,
              _getEditionNameRow(context, assetToken),
            ],
          )
        else
          const SizedBox(),
        divider,
        MetaDataItem(
          title: 'token'.tr(),
          value: polishSource(assetToken.source ?? ''),
          tapLink: assetToken.isAirdrop ? null : assetToken.assetURL,
          forceSafariVC: true,
        ),
        divider,
        if (assetToken.source == 'feralfile' && artworkID.isNotEmpty)
          FutureBuilder<Exhibition?>(
            future: injector<FeralFileService>()
                // ignore: discarded_futures
                .getExhibitionFromTokenID(artworkID),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                return Column(
                  children: [
                    MetaDataItem(
                      title: 'exhibition'.tr(),
                      value: snapshot.data!.title,
                      onTap: () {
                        unawaited(
                          Navigator.of(context).pushNamed(
                            AppRouter.exhibitionDetailPage,
                            arguments: ExhibitionDetailPayload(
                              exhibitions: [snapshot.data!],
                              index: 0,
                            ),
                          ),
                        );
                      },
                      forceSafariVC: true,
                    ),
                    divider,
                  ],
                );
              } else {
                return const SizedBox();
              }
            },
          )
        else
          const SizedBox(),
        MetaDataItem(
          title: 'contract'.tr(),
          value: assetToken.blockchain.capitalize(),
          tapLink: assetToken.getBlockchainUrl(),
          forceSafariVC: true,
        ),
        divider,
        MetaDataItem(
          title: 'medium'.tr(),
          value: assetToken.medium?.capitalize() ?? '',
        ),
        if (assetToken.mintedAt != null) ...[
          divider,
          MetaDataItem(
            title: 'date_minted'.tr(),
            value: assetToken.mintedAt != null
                ? localTimeString(assetToken.mintedAt!)
                : '',
          ),
        ],
        if (assetToken.assetData != null && assetToken.assetData!.isNotEmpty)
          Column(
            children: [
              const Divider(height: 32),
              MetaDataItem(
                title: 'artwork_data'.tr(),
                value: assetToken.assetData!,
              ),
            ],
          )
        else
          const SizedBox(),
        const SizedBox(
          height: 32,
        ),
      ],
    ),
  );
}

Widget _getEditionNameRow(BuildContext context, AssetToken assetToken) {
  if (assetToken.editionName != null && assetToken.editionName != '') {
    return MetaDataItem(
      title: 'edition'.tr(),
      value: assetToken.editionName!,
    );
  }
  return MetaDataItem(
    title: 'edition'.tr(),
    value: assetToken.edition.toString(),
  );
}

Widget tokenOwnership(
  BuildContext context,
  AssetToken assetToken,
  String alias,
) {
  final ownedTokens = assetToken.balance ?? 0;
  final ownerAddress = assetToken.owner;
  final tapLink = assetToken.tokenURL;

  const divider = artworkDataDivider;

  return SectionExpandedWidget(
    header: 'token_ownership'.tr(),
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        if ((assetToken.maxEdition ?? 0) > 0) ...[
          MetaDataItem(
            title: 'editions'.tr(),
            value: '${assetToken.maxEdition}',
            tapLink: assetToken.tokenURL,
            forceSafariVC: true,
          ),
          divider,
        ],
        MetaDataItem(
          title: 'token_holder'.tr(),
          value: alias.isNotEmpty ? alias : ownerAddress.maskOnly(5),
          forceSafariVC: true,
        ),
        divider,
        MetaDataItem(
          title: 'token_held'.tr(),
          value: ownedTokens.toString(),
          tapLink: tapLink,
          forceSafariVC: true,
        ),
      ],
    ),
  );
}

class CustomMetaDataItem extends StatelessWidget {
  const CustomMetaDataItem({
    required this.title,
    required this.content,
    super.key,
    this.titleStyle,
    this.forceSafariVC,
  });

  final String title;
  final TextStyle? titleStyle;
  final Widget content;
  final bool? forceSafariVC;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: titleStyle ?? theme.textTheme.ppMori400Grey14,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(flex: 3, child: content),
      ],
    );
  }
}

class MetaDataItem extends StatelessWidget {
  const MetaDataItem({
    required this.title,
    required this.value,
    super.key,
    this.titleStyle,
    this.onTap,
    this.tapLink,
    this.forceSafariVC,
    this.linkStyle,
    this.valueStyle,
  });

  final String title;
  final TextStyle? titleStyle;
  final String value;
  final TextStyle? valueStyle;
  final Function()? onTap;
  final String? tapLink;
  final bool? forceSafariVC;
  final TextStyle? linkStyle;

  @override
  Widget build(BuildContext context) {
    var onValueTap = onTap;

    if (onValueTap == null && tapLink != null) {
      final uri = Uri.parse(tapLink!);
      onValueTap = () async => launchUrl(
            uri,
            mode: forceSafariVC == true
                ? LaunchMode.externalApplication
                : LaunchMode.platformDefault,
          );
    }
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: titleStyle ?? theme.textTheme.ppMori400Grey12,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onValueTap,
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: onValueTap != null
                  ? linkStyle ?? theme.textTheme.ppMori400FFYellow12
                  : valueStyle ?? theme.textTheme.ppMori400White12,
            ),
          ),
        ),
      ],
    );
  }
}

class ProvenanceItem extends StatelessWidget {
  const ProvenanceItem({
    required this.title,
    required this.value,
    super.key,
    this.onTap,
    this.tapLink,
    this.forceSafariVC,
    this.onNameTap,
  });

  final String title;
  final String value;
  final Function()? onTap;
  final Function()? onNameTap;
  final String? tapLink;
  final bool? forceSafariVC;

  @override
  Widget build(BuildContext context) {
    var onValueTap = onTap;

    if (onValueTap == null && tapLink != null) {
      final uri = Uri.parse(tapLink!);
      onValueTap = () async => launchUrl(
            uri,
            mode: forceSafariVC == true
                ? LaunchMode.externalApplication
                : LaunchMode.platformDefault,
          );
    }
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: onNameTap,
            child: Text(
              title,
              style: theme.textTheme.ppMori400White12,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: theme.textTheme.ppMori400White12,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onValueTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColor.feralFileHighlight,
                    ),
                    borderRadius: BorderRadius.circular(64),
                  ),
                  child: Text(
                    'view'.tr(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.ppMori400FFYellow12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget artworkDetailsProvenanceSectionNotEmpty(
  BuildContext context,
  List<Provenance> provenances,
  HashSet<String> youAddresses,
  Map<String, String> identityMap,
) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionExpandedWidget(
          header: 'provenance'.tr(),
          padding: const EdgeInsets.only(bottom: 23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...provenances.map((el) {
                final identity = identityMap[el.owner];
                final identityTitle = el.owner.toIdentityOrMask(identityMap);
                final youTitle =
                    youAddresses.contains(el.owner) ? '_you'.tr() : '';
                return Column(
                  children: [
                    ProvenanceItem(
                      title: (identityTitle ?? '') + youTitle,
                      value: localTimeString(el.timestamp),
                      // subTitle: el.blockchain.toUpperCase(),
                      tapLink: el.txURL,
                      onNameTap: () => identity != null
                          ? unawaited(
                              UIHelper.showIdentityDetailDialog(
                                context,
                                name: identity,
                                address: el.owner,
                              ),
                            )
                          : null,
                      forceSafariVC: true,
                    ),
                    if (el != provenances.last) artworkDataDivider,
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );

class ArtworkRightsView extends StatefulWidget {
  const ArtworkRightsView({
    super.key,
    this.contractAddress,
    this.linkStyle,
    this.artworkID,
    this.exhibitionID,
  });

  final TextStyle? linkStyle;
  final String? contractAddress;
  final String? artworkID;
  final String? exhibitionID;

  @override
  State<ArtworkRightsView> createState() => _ArtworkRightsViewState();
}

class _ArtworkRightsViewState extends State<ArtworkRightsView> {
  @override
  void initState() {
    super.initState();
    context.read<RoyaltyBloc>().add(
          GetRoyaltyInfoEvent(
            exhibitionID: widget.exhibitionID,
            artworkID: widget.artworkID,
            contractAddress: widget.contractAddress ?? '',
          ),
        );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<RoyaltyBloc, RoyaltyState>(
        builder: (context, state) {
          final data = state.markdownData?.replaceAll('.**', '**');
          return SectionExpandedWidget(
            header: 'collector_rights'.tr(),
            padding: const EdgeInsets.only(bottom: 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data == null)
                  Center(
                    child: loadingIndicator(
                      backgroundColor: AppColor.white,
                      valueColor: AppColor.auGreyBackground,
                    ),
                  )
                else
                  Markdown(
                    key: const Key('rightsSection'),
                    data: data,
                    softLineBreak: true,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    styleSheet: markDownRightStyle(context),
                    onTapLink: (text, href, title) async {
                      if (href == null) {
                        return;
                      }
                      await launchUrl(
                        Uri.parse(href),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                const SizedBox(height: 23),
              ],
            ),
          );
        },
      );
}

class ArtworkDetailsHeader extends StatelessWidget {
  const ArtworkDetailsHeader({
    required this.title,
    required this.subTitle,
    super.key,
    this.hideArtist = false,
    this.onTitleTap,
    this.onSubTitleTap,
    this.isReverse = false,
    this.color,
  });

  final String title;
  final String subTitle;
  final bool hideArtist;
  final Function? onTitleTap;
  final Function? onSubTitleTap;
  final bool isReverse;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideArtist)
          GestureDetector(
            onTap: () {
              onSubTitleTap?.call();
            },
            child: Text(
              subTitle,
              style: theme.textTheme.ppMori700White14.copyWith(
                color: color ?? AppColor.white,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        GestureDetector(
          onTap: () {
            onTitleTap?.call();
          },
          child: Text(
            title,
            style: theme.textTheme.ppMori400White14.copyWith(
              color: color ?? AppColor.white,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class DrawerItem extends StatefulWidget {
  const DrawerItem({
    required this.item,
    this.color,
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 13),
  });

  final OptionItem item;
  final Color? color;
  final EdgeInsets padding;

  @override
  State<DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<DrawerItem> {
  late bool isProcessing;

  @override
  void initState() {
    isProcessing = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final color = widget.color;
    final defaultTextStyle = theme.textTheme.ppMori400Black14;
    final customTextStyle = defaultTextStyle.copyWith(color: color);
    final defaultProcessingTextStyle =
        defaultTextStyle.copyWith(color: AppColor.disabledColor);
    final defaultDisabledTextStyle =
        defaultTextStyle.copyWith(color: AppColor.disabledColor);
    final icon = !item.isEnable
        ? item.iconOnDisable
        : isProcessing
            ? (item.iconOnProcessing ??
                loadingIndicator(valueColor: AppColor.disabledColor, size: 14))
            : item.icon;
    final titleStyle = !item.isEnable
        ? (item.titleStyleOnDisable ?? defaultDisabledTextStyle)
        : isProcessing
            ? (item.titleStyleOnPrecessing ?? defaultProcessingTextStyle)
            : (item.titleStyle ?? customTextStyle);

    final child = Container(
      color: Colors.transparent,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 30,
                child: Center(
                  child: icon,
                ),
              ),
              const SizedBox(
                width: 34,
              ),
            ],
            Text(
              item.title ?? '',
              style: titleStyle,
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onTap: () async {
        if (!item.isEnable) {
          return;
        }
        if (isProcessing) {
          return;
        }
        setState(() {
          isProcessing = true;
        });
        await item.onTap?.call();
        if (mounted) {
          setState(() {
            isProcessing = false;
          });
        }
      },
      child: child,
    );
  }
}
