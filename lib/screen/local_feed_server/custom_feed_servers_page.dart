import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/custom_feed_servers_bloc.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/custom_feed_servers_event.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/custom_feed_servers_state.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';

class CustomFeedServersPage extends StatefulWidget {
  const CustomFeedServersPage({super.key});

  @override
  State<CustomFeedServersPage> createState() => _CustomFeedServersPageState();
}

class _CustomFeedServersPageState extends State<CustomFeedServersPage>
    with RouteAware {
  late final CustomFeedServersBloc _bloc;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _bloc = CustomFeedServersBloc()..add(LoadCustomFeedServersEvent());
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _bloc.add(LoadCustomFeedServersEvent());
  }

  @override
  void dispose() {
    _bloc.close();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocProvider(
      create: (_) => _bloc,
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: const MainAppBar(backTitle: 'Index'),
        body: BlocBuilder<CustomFeedServersBloc, CustomFeedServersState>(
          builder: (context, state) {
            if (state.isLoading) {
              return _loadingView(context);
            }

            if (state.feedServices.isEmpty) {
              return _emptyView(context);
            }

            return Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 64),
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollController,
                        shrinkWrap: true,
                        slivers: [
                          ...state.feedServices
                              .map((feedService) => UIHelper
                                      .customFeedServerExpandableSliverStickyHeader(
                                          context,
                                          playlists: feedService
                                              .getAllCachedPlaylists()
                                              .map((playlist) =>
                                                  PlaylistReference(
                                                      playlist: playlist,
                                                      url: feedService.baseUrl))
                                              .toList(),
                                          title: feedService.baseUrl,
                                          scrollController: _scrollController,
                                          slidableActions: [
                                        CustomSlidableAction(
                                          backgroundColor:
                                              AppColor.primaryBlack,
                                          padding: EdgeInsets.zero,
                                          onPressed:
                                              (BuildContext context) async {
                                            UIHelper
                                                .showDeleteFeedServerConfirmation(
                                                    feedService, (feedService) {
                                              _bloc.add(
                                                  RemoveCustomFeedServerEvent(
                                                      feedService.baseUrl));
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
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
                                        )
                                      ]))
                              .toList(),
                          SliverToBoxAdapter(child: const SizedBox(height: 32)),
                          const SliverToBoxAdapter(child: BottomSpacing()),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Padding(
                        padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                        child: _addCustomFeedServerButton(context),
                      ),
                      const BottomSpacing(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _loadingView(BuildContext context) {
    return LoadingWidget(
      backgroundColor: AppColor.auGreyBackground,
    );
  }

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('No custom feed servers yet',
            style: theme.textTheme.ppMori400Grey14),
        const SizedBox(height: 16),
        Padding(
          padding: ResponsiveLayout.pageHorizontalEdgeInsets,
          child: _addCustomFeedServerButton(context),
        ),
        const BottomSpacing(),
      ],
    );
  }

  Widget _addCustomFeedServerButton(BuildContext context) {
    return PrimaryButton(
      onTap: () {
        injector<NavigationService>()
            .navigateTo(AppRouter.addLocalFeedServerPage);
      },
      text: 'Add Custom Feed Server',
    );
  }
}
