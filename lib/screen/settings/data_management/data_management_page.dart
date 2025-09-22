//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_bloc.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_view.dart';
import 'package:autonomy_flutter/service/client_token_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/feed_cache_manager.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = ResponsiveLayout.pageEdgeInsets.copyWith(top: 0, bottom: 0);
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'data_management'.tr(),
        onBack: () {
          Navigator.of(context).pop();
        },
      ),
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
                          style: ResponsiveLayout.isMobile
                              ? theme.textTheme.ppMori400Black16
                              : theme.textTheme.ppMori400Black16,
                        ),
                        bottomWidget: Text(
                          'clear_cache'.tr(),
                          style: ResponsiveLayout.isMobile
                              ? theme.textTheme.ppMori400Black14
                              : theme.textTheme.ppMori400Black16,
                        ),
                        onTap: _showRebuildGalleryDialog,
                      ),
                    ),
                    addDivider(height: 16),
                    Padding(
                      padding: padding,
                      child: TappableForwardRowWithContent(
                        leftWidget: Text(
                          'forget_exist'.tr(),
                          style: ResponsiveLayout.isMobile
                              ? theme.textTheme.ppMori400Black16
                              : theme.textTheme.ppMori400Black16,
                        ),
                        bottomWidget: Text(
                          'erase_all'.tr(),
                          style: ResponsiveLayout.isMobile
                              ? theme.textTheme.ppMori400Black14
                              : theme.textTheme.ppMori400Black16,
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
            injector(),
            injector(),
            injector<NftCollectionBloc>().database,
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
          await injector<NftTokensService>().purgeCachedGallery();
          await injector<CacheManager>().emptyCache();
          await DefaultCacheManager().emptyCache();
          await injector<ClientTokenService>()
              .refreshTokens(syncAddresses: true);
          NftCollectionBloc.eventController
              .add(GetTokensByOwnerEvent(pageKey: PageKey.init()));
          injector<UserAllOwnCollectionBloc>().add(ClearDataEvent());
          final dynamicQuery = injector<UserDp1PlaylistService>()
              .cachedAllOwnedPlaylist
              .firstDynamicQuery;
          if (dynamicQuery != null) {
            injector<UserAllOwnCollectionBloc>()
                .add(UpdateDynamicQueryEvent(dynamicQuery: dynamicQuery));
          }
          injector<FeedCacheManager>()
            ..clearAll()
            ..reloadCache();

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
