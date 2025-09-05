//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_rendering/svg_image.dart';
import 'package:autonomy_flutter/screen/settings/hidden_artworks/hidden_artworks_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;

class HiddenArtworksPage extends StatefulWidget {
  const HiddenArtworksPage({super.key});

  @override
  State<HiddenArtworksPage> createState() => _HiddenArtworksPageState();
}

class _HiddenArtworksPageState extends State<HiddenArtworksPage> {
  int _cachedImageSize = 0;

  @override
  void initState() {
    super.initState();

    context.read<HiddenArtworksBloc>().add(HiddenArtworksEvent());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            getBackAppBar(context, title: 'hidden_artwork'.tr(), onBack: () {
          Navigator.of(context).pop();
        }),
        body: BlocBuilder<HiddenArtworksBloc, List<CompactedAssetToken>>(
            builder: (context, state) => Container(
                  child: state.isEmpty
                      ? _emptyHiddenArtwork(context)
                      : _assetsWidget(state),
                )),
      );

  Widget _emptyHiddenArtwork(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: ResponsiveLayout.pageEdgeInsets.copyWith(top: 0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          addTitleSpace(),
          Text(
            'no_hidden_artwork'.tr(),
            style: theme.textTheme.ppMori400Black16,
            textAlign: TextAlign.start,
          ),
          const SizedBox(
            height: 12,
          ),
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'to_hide_an_artowrk'.tr(),
                  style: theme.textTheme.ppMori400Black14,
                ),
                WidgetSpan(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        size: 15,
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: 'and_select'.tr(),
                  style: theme.textTheme.ppMori400Black14,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _assetsWidget(List<CompactedAssetToken> tokens) {
    const int cellPerRowPhone = 3;
    const int cellPerRowTablet = 6;
    const double cellSpacing = 3;
    int cellPerRow =
        ResponsiveLayout.isMobile ? cellPerRowPhone : cellPerRowTablet;

    if (_cachedImageSize == 0) {
      final estimatedCellWidth =
          MediaQuery.of(context).size.width / cellPerRow -
              cellSpacing * (cellPerRow - 1);
      _cachedImageSize = (estimatedCellWidth * 3).ceil();
    }

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 3,
          ),
        ),
        SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cellPerRow,
              crossAxisSpacing: cellSpacing,
              mainAxisSpacing: cellSpacing,
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                final asset = tokens[index];
                final thumbnailUrl = asset.getGalleryThumbnailUrl();

                final ext = p.extension(thumbnailUrl ?? '');
                return GestureDetector(
                  child: Stack(
                    children: [
                      if (thumbnailUrl == null || thumbnailUrl.isEmpty)
                        GalleryNoThumbnailWidget(
                          assetToken: asset,
                        )
                      else
                        Hero(
                          tag: asset.id,
                          child: ext == '.svg'
                              ? SvgImage(
                                  url: thumbnailUrl,
                                  loadingWidgetBuilder: (_) =>
                                      const GalleryThumbnailPlaceholder(),
                                  errorWidgetBuilder: (_) =>
                                      const GalleryThumbnailErrorWidget(),
                                  unsupportWidgetBuilder: (context) =>
                                      const GalleryUnSupportThumbnailWidget(),
                                )
                              : CachedNetworkImage(
                                  imageUrl: thumbnailUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  cacheManager: injector<CacheManager>(),
                                  maxHeightDiskCache: _cachedImageSize,
                                  maxWidthDiskCache: _cachedImageSize,
                                  memCacheHeight: _cachedImageSize,
                                  memCacheWidth: _cachedImageSize,
                                  placeholder: _loadingBuilder,
                                  errorWidget: (context, url, error) =>
                                      const GalleryThumbnailErrorWidget(),
                                ),
                        ),
                      ClipRRect(
                        // Clip it cleanly.
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          alignment: Alignment.center,
                          child: const Icon(
                            AuIcon.hidden_artwork,
                            color: AppColor.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    const isHidden = true;
                    await injector<ConfigurationService>()
                        .updateTempStorageHiddenTokenIDs([asset.id], !isHidden);
                    unawaited(
                        injector<SettingsDataService>().backupUserSettings());
                    NftCollectionBloc.eventController.add(ReloadEvent());

                    if (!context.mounted) {
                      return;
                    }
                    unawaited(UIHelper.showHideArtworkResultDialog(
                        context, !isHidden, onOK: () {
                      Navigator.of(context).pop();
                      context
                          .read<HiddenArtworksBloc>()
                          .add(HiddenArtworksEvent());
                    }));
                  },
                );
              },
              childCount: tokens.length,
            )),
        SliverToBoxAdapter(
            child: Container(
          height: 56,
        ))
      ],
      controller: ScrollController(),
    );
  }

  Widget _loadingBuilder(BuildContext context, url) =>
      const GalleryThumbnailPlaceholder();
}
