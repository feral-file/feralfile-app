import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/screen/detail/royalty/royalty_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/metric_client_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/color_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/datetime_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

// String getEditionSubTitle(AssetToken token) {
//   if (token.editionName != null && token.editionName != '') {
//     return token.editionName!;
//   }
//   if (token.edition == 0) {
//     return '';
//   }
//   return token.maxEdition != null && token.maxEdition! >= 1
//       ? tr(
//           'edition_of',
//           args: [token.edition.toString(), token.maxEdition.toString()],
//         )
//       : '${tr('edition')} ${token.edition}';
// }

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

final Map<String, Future<bool>> _cachingStates = {};

Widget tokenGalleryThumbnailWidget(
  BuildContext context,
  AssetToken token,
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

  final memCacheWidth = cachedImageSize;
  final memCacheHeight = memCacheWidth ~/ ratio;

  return FFArtworkThumbnailView(
    url: thumbnailUrl,
    fit: BoxFit.cover,
    cacheWidth: memCacheWidth,
    cacheHeight: memCacheHeight,
    placeholder:
        galleryThumbnailPlaceholder ?? const GalleryThumbnailPlaceholder(),
    errorWidget: FFArtworkThumbnailView(
      url: token.getGalleryThumbnailUrl(usingThumbnailID: false) ?? '',
      fit: BoxFit.cover,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      placeholder:
          galleryThumbnailPlaceholder ?? const GalleryThumbnailPlaceholder(),
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
  const GalleryNoThumbnailWidget({this.assetToken, super.key});

  final AssetToken? assetToken;

  String getAssetDefault() {
    switch (assetToken?.getMimeType) {
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
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final dynamicPadding = min(10.0, side * 0.03);
        final iconSize = min(24.0, side * 0.3);

        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: EdgeInsets.all(dynamicPadding),
            color: theme.auLightGrey,
            child: Stack(
              children: [
                if (iconSize > 0)
                  Center(
                    child: SvgPicture.asset(
                      getAssetDefault(),
                      width: iconSize,
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      alignment: AlignmentDirectional.bottomStart,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'no_thumbnail'.tr(),
                        style: theme.textTheme.ppMori700QuickSilver8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NoPreviewWidget extends StatelessWidget {
  const NoPreviewWidget({this.assetToken, super.key});

  final AssetToken? assetToken;

  String getAssetDefault() {
    switch (assetToken?.getMimeType) {
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
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final dynamicPadding = min(10.0, side * 0.03);
        final iconSize = min(24.0, side * 0.3);

        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: EdgeInsets.all(dynamicPadding),
            color: theme.auLightGrey,
            child: iconSize > 0
                ? Center(
                    child: SvgPicture.asset(
                      getAssetDefault(),
                      width: iconSize,
                    ),
                  )
                : null,
          ),
        );
      },
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

Widget artworkDetailsRightSection(BuildContext context, AssetToken assetToken) {
  // if (assetToken.shouldShowFeralfileRight) {
  //   final artworkID = assetToken.feralfileArtworkId;
  //   return ArtworkRightsView(
  //     contractAddress: assetToken.contractAddress,
  //     artworkID: artworkID,
  //   );
  // }
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
    this.isExpandedDefault = false,
  });

  final String? header;
  final TextStyle? headerStyle;
  final EdgeInsets? headerPadding;
  final Widget? child;
  final Widget? iconOnExpanded;
  final Widget? iconOnUnExpanded;
  final bool withDivider;
  final EdgeInsets padding;
  final bool isExpandedDefault;

  @override
  State<SectionExpandedWidget> createState() => _SectionExpandedWidgetState();
}

class _SectionExpandedWidgetState extends State<SectionExpandedWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpandedDefault;
  }

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
                  padding: EdgeInsets.only(top: 16),
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

Widget artworkDetailsMetadataSection(
  BuildContext context,
  AssetToken assetToken,
  String? artistName,
) {
  const divider = artworkDataDivider;
  final publisherName = assetToken.publisher?.name;
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
            onTap: null,
            forceSafariVC: true,
          ),
        ],
        divider,
        if (publisherName != null) ...[
          MetaDataItem(
            title: 'token'.tr(),
            value: publisherName,
            tapLink: assetToken.publisher?.url,
            forceSafariVC: true,
          ),
          divider,
        ],
        MetaDataItem(
          title: 'contract'.tr(),
          value: assetToken.blockchain.name,
          tapLink: assetToken.getBlockchainUrl(),
          forceSafariVC: true,
        ),
        // divider,
        // MetaDataItem(
        //   title: 'medium'.tr(),
        //   value: assetToken.medium?.capitalize() ?? '',
        // ),
        const SizedBox(
          height: 32,
        ),
      ],
    ),
  );
}

Widget tokenOwnership(
  BuildContext context,
  AssetToken assetToken,
  String alias,
) {
  final allAddresses = injector<AddressService>().getAllAddresses();
  final ownedTokens = assetToken.owners?.items
      .firstWhereOrNull(
          (element) => allAddresses.contains(element.ownerAddress))
      ?.quantity;
  final ownerAddress = assetToken.owners?.items
      .firstWhereOrNull(
          (element) => allAddresses.contains(element.ownerAddress))
      ?.ownerAddress;
  final tapLink = assetToken.secondaryMarketURL;

  const divider = artworkDataDivider;

  return SectionExpandedWidget(
    header: 'token_ownership'.tr(),
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaDataItem(
          title: 'token_holder'.tr(),
          value: alias.isNotEmpty ? alias : ownerAddress?.maskOnly(5) ?? '',
          forceSafariVC: true,
        ),
        if (ownedTokens != null) ...[
          divider,
          MetaDataItem(
            title: 'token_held'.tr(),
            value: ownedTokens.toString(),
            tapLink: tapLink,
            forceSafariVC: true,
          ),
        ],
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
  List<ProvenanceEvent> provenances,
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
                final identity = identityMap[el.toAddress];
                final identityTitle =
                    el.toAddress?.toIdentityOrMask(identityMap) ?? '';
                final youTitle =
                    youAddresses.contains(el.toAddress) ? '_you'.tr() : '';
                if (el.toAddress == null) {
                  return SizedBox();
                }
                return Column(
                  children: [
                    ProvenanceItem(
                      title: (identityTitle) + youTitle,
                      value: localTimeString(el.timestamp),
                      // subTitle: el.blockchain.toUpperCase(),
                      tapLink: el.txUrl,
                      onNameTap: () => identity != null
                          ? unawaited(
                              UIHelper.showIdentityDetailDialog(
                                context,
                                name: identity,
                                address: el.toAddress ?? '',
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
    final defaultTextStyle = theme.textTheme.ppMori400Black12;
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
