import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_bloc.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_state.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:autonomy_flutter/widgets/ff_text_field/ff_text_field.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin<CollectionPage> {
  late final UserAllOwnCollectionBloc _collectionBloc;
  late final ViewExistingAddressBloc _addressBloc;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _collectionBloc = injector<UserAllOwnCollectionBloc>();
    _addressBloc = ViewExistingAddressBloc(injector(), injector());
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _autoRefresh();
  }

  void _autoRefresh() async {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        final allOwnedPlaylist =
            await injector<UserDp1PlaylistService>().cachedAllOwnedPlaylist;
        final dynamicQuery = allOwnedPlaylist.firstDynamicQuery;
        if (!mounted) return;
        if (dynamicQuery != null) {
          _collectionBloc
              .add(UpdateDynamicQueryEvent(dynamicQuery: dynamicQuery));
        }
      } catch (_) {
        // Silently ignore refresh errors
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _collectionBloc.close();
    _addressBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Builder(
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: BlocBuilder<ViewExistingAddressBloc,
                      ViewExistingAddressState>(
                    bloc: _addressBloc,
                    builder: (context, addressState) {
                      return FFTextField(
                        active: true,
                        placeholder: 'Type or Paste Address / Domain',
                        isError: addressState.isError,
                        isLoading: addressState.isAddConnectionLoading,
                        errorMessage: addressState.exception?.message ??
                            (addressState.isError ? 'Invalid address' : null),
                        onChanged: (text) {
                          _addressBloc.add(AddressChangeEvent(text));
                        },
                        onSend: (text) {
                          _addressBloc.add(AddConnectionEvent());
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                BlocBuilder<UserAllOwnCollectionBloc,
                    UserAllOwnCollectionState>(
                  bloc: _collectionBloc,
                  builder: (context, collectionState) {
                    return FFCastButton(
                      onDeviceSelected: (device) async {
                        final allOwnedPlaylist =
                            await injector<UserDp1PlaylistService>()
                                .allOwnedPlaylist();
                        injector<CanvasDeviceBloc>().add(
                          CanvasDeviceCastDP1PlaylistEvent(
                            device: device,
                            playlist: allOwnedPlaylist,
                            intent: DP1Intent.displayNow(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: BlocBuilder<UserAllOwnCollectionBloc,
                  UserAllOwnCollectionState>(
                bloc: _collectionBloc,
                builder: (context, collectionState) {
                  if (collectionState.isError) {
                    return Center(
                      child: Text(
                        'Error: ${collectionState.error}',
                        style: const TextStyle(color: AppColor.white),
                      ),
                    );
                  } else {
                    return Stack(
                      children: [
                        CustomScrollView(
                          shrinkWrap: true,
                          slivers: [
                            if (collectionState.compactedAssetTokens.isNotEmpty)
                              UIHelper.assetTokenSliverGrid(
                                context,
                                collectionState.compactedAssetTokens,
                                'Collection',
                              )
                            else
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 32, horizontal: 12),
                                  child: Text(
                                    'collection_empty_now'.tr(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .ppMori400White12,
                                  ),
                                ),
                              ),
                            if (collectionState.isLazyLoading &&
                                collectionState.compactedAssetTokens.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                      child: LoadMoreIndicator(
                                          isLoadingMore: true)),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: BottomSpacing(),
                            )
                          ],
                        ),
                        // Loading overlay when loading and no tokens yet
                        if (collectionState.isLazyLoading &&
                            collectionState.compactedAssetTokens.isEmpty)
                          Container(
                            color: Colors.black.withOpacity(0.3),
                            child: const Center(
                              child: LoadingWidget(
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
