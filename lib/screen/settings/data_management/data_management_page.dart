//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc_manager.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_bloc.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_view.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/tappable_forward_row.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  UserAllOwnCollectionBloc? _userAllOwnCollectionBloc;

  @override
  void initState() {
    super.initState();
    final addresses = injector<AddressService>().getAllAddresses();
    if (addresses.isNotEmpty) {
      final manager = injector<UserAllOwnCollectionBlocManager>();
      _userAllOwnCollectionBloc = manager.getOrCreateBloc(addresses);
    }
  }

  @override
  void dispose() {
    if (_userAllOwnCollectionBloc != null) {
      injector<UserAllOwnCollectionBlocManager>()
          .releaseBlocByInstance(_userAllOwnCollectionBloc!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = ResponsiveLayout.pageEdgeInsets.copyWith(top: 0, bottom: 0);
    return Scaffold(
      appBar: getBackAppBar(context, title: 'data_management'.tr(), onBack: () {
        Navigator.of(context).pop();
      }, backgroundColor: AppColor.auGreyBackground, isWhite: false),
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Column(
          children: [
            addTitleSpace(),
            Column(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: padding,
                      child: TappableForwardRowWithContent(
                        leftWidget: Text(
                          'rebuild_metadata'.tr(),
                          style: AppTypography.body(context).white,
                        ),
                        bottomWidget: Text(
                          'clear_cache'.tr(),
                          style: AppTypography.body(context).grey,
                        ),
                        onTap: _showRebuildGalleryDialog,
                      ),
                    ),
                    addDivider(height: 16, color: AppColor.primaryBlack),
                    Padding(
                      padding: padding,
                      child: TappableForwardRowWithContent(
                        leftWidget: Text(
                          'forget_exist'.tr(),
                          style: AppTypography.body(context).white,
                        ),
                        bottomWidget: Text(
                          'erase_all'.tr(),
                          style: AppTypography.body(context).grey,
                        ),
                        onTap: _showForgetIExistDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showForgetIExistDialog() {
    unawaited(
      UIHelper.showDialog(
        context,
        'forget_exist'.tr(),
        BlocProvider(
          create: (_) => ForgetExistBloc(
            injector<IndexerDatabaseAbstract>(),
            injector(),
          ),
          child: const ForgetExistView(),
        ),
      ),
    );
  }

  void _showRebuildGalleryDialog() {
    unawaited(
      showErrorDialog(
        context,
        'rebuild_metadata'.tr(),
        'this_action_clear'.tr(),
        //"This action will safely clear local cache and\nre-download all artwork metadata. We recommend only doing this if instructed to do so by customer support to resolve a problem.",
        'rebuild'.tr(),
        () async {
          // remove all cached data
          await injector<NftTokensService>().purgeCachedGallery();
          await injector<UserDp1PlaylistService>()
              .setLastUpdateChangeAnchor(addressAnchors: []);
          await injector<UserDp1PlaylistService>()
              .setLastUpdateChangeAnchor(addressAnchors: []);
          await injector<CacheManager>().emptyCache();
          await DefaultCacheManager().emptyCache();
          final manager = injector<UserAllOwnCollectionBlocManager>();
          await manager.disposeAll();
          injector<FeralFileFeedManager>().clearAllCache();
          //redownload data
          final addresses = injector<AddressService>().getAllAddresses();
          if (addresses.isNotEmpty) {
            // Get or create new bloc after disposeAll
            _userAllOwnCollectionBloc
                ?.add(ReloadAssetTokensFromIndexerDatabase());
            _userAllOwnCollectionBloc
                ?.add(FetchTokens(shouldUpdateLastRefreshedTime: true));
          }
          unawaited(
              injector<FeralFileFeedManager>().reloadAllCache(force: true));

          if (!mounted) {
            return;
          }
          context.read<IdentityBloc>().add(RemoveAllEvent());
          Navigator.of(context).popUntil(
            (route) =>
                route.settings.name == AppRouter.homePage ||
                route.settings.name == AppRouter.homePage,
          );
        },
        'cancel'.tr(),
      ),
    );
  }
}
