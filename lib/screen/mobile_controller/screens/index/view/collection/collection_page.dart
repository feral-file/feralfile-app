import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/view/record_controller.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:autonomy_flutter/widgets/notice-banner/notice_banner.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin<CollectionPage> {
  late final UserAllOwnCollectionBloc _collectionBloc;
  late final ViewExistingAddressBloc _addressBloc;
  bool _isNoticeBannerVisible = true;
  Timer? _autoRefreshTimer;

  late final ScrollController _scrollController;
  late final StickyHeaderController _stickyHeaderController;

  final Map<String, bool> _expandedAddressesMap = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _stickyHeaderController = StickyHeaderController();
    _collectionBloc = injector<UserAllOwnCollectionBloc>();
    _addressBloc = ViewExistingAddressBloc(injector(), injector());
  }

  @override
  void afterFirstLayout(BuildContext context) {}

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
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
            BlocBuilder<UserAllOwnCollectionBloc, UserAllOwnCollectionState>(
              bloc: _collectionBloc,
              builder: (context, collectionState) {
                return Padding(
                  padding: ResponsiveLayout.pageHorizontalEdgeInsets
                      .copyWith(bottom: 10),
                  child: Row(
                    children: [
                      FFCastButton(
                        onDeviceSelected: (device) async {
                          final allOwnedPlaylist =
                              await injector<UserDp1PlaylistService>()
                                  .allOwnedPlaylist();
                          final completer = Completer<void>();
                          injector<CanvasDeviceBloc>().add(
                            CanvasDeviceCastDP1PlaylistEvent(
                              device: device,
                              playlist: allOwnedPlaylist,
                              intent: DP1Intent.displayNow(),
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
                );
              },
            ),
            if (_isNoticeBannerVisible)
              Column(
                children: [
                  Padding(
                    padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                    child: NoticeBanner(
                      message: '''
Type or paste an address into the command bar to load''',
                      onClose: () {
                        setState(() {
                          _isNoticeBannerVisible = false;
                        });
                      },
                      onTap: () {
                        injector<NavigationService>().popToRouteOrPush(
                          AppRouter.voiceCommandPage,
                          arguments: RecordControllerScreenPayload(
                            isListening: false,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
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
                  } else if (collectionState.addressAssetTokens.isEmpty) {
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              'collection_empty_now'.tr(),
                              style: Theme.of(context).textTheme.small,
                            ),
                          ),
                        ),
                        const BottomSpacing()
                      ],
                    );
                  } else {
                    return Stack(
                      children: [
                        CustomScrollView(
                          controller: _scrollController,
                          shrinkWrap: true,
                          slivers: [
                            if (collectionState.addressAssetTokens.isNotEmpty)
                              ...collectionState.addressAssetTokens.map(
                                (addressAssetToken) {
                                  final address =
                                      addressAssetToken.address.address;
                                  return UIHelper
                                      .assetTokenExpandableSliverStickyHeader(
                                          context,
                                          compactedAssetTokens:
                                              addressAssetToken
                                                  .compactedAssetTokens,
                                          title: addressAssetToken.address.name,
                                          isExpanded:
                                              _expandedAddressesMap[address] ??
                                                  false,
                                          onExpandedChanged: (isExpanded) {
                                    _expandedAddressesMap[address] = isExpanded;
                                  },
                                          scrollController: _scrollController,
                                          slidableActions: [
                                        CustomSlidableAction(
                                          backgroundColor:
                                              AppColor.primaryBlack,
                                          padding: EdgeInsets.zero,
                                          onPressed:
                                              (BuildContext context) async {
                                            final address =
                                                addressAssetToken.address;
                                            UIHelper
                                                .showDeleteAccountConfirmation(
                                                    address, (address) async {
                                              await injector<AddressService>()
                                                  .deleteAddress(address);
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 16),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/images/trash.svg',
                                                  height: 15,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Delete',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .ppMori400White12,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ]);
                                },
                              ).toList(),
                            if (collectionState.isLazyLoading &&
                                collectionState.addressAssetTokens.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                      child: LoadMoreIndicator(
                                          isLoadingMore: true)),
                                ),
                              ),
                            const SliverToBoxAdapter(
                              child: BottomSpacing(),
                            )
                          ],
                        ),
                        // Loading overlay when loading and no tokens yet
                        if (collectionState.isLazyLoading &&
                            collectionState.addressAssetTokens.isEmpty)
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
