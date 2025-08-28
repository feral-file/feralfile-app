import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_token_item_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DP1NowDisplayingExpandedView extends StatefulWidget {
  const DP1NowDisplayingExpandedView({
    required this.playlist,
    this.selectedIndex,
    super.key,
  });

  final DP1Call playlist;
  final int? selectedIndex;

  @override
  State<DP1NowDisplayingExpandedView> createState() =>
      _DP1NowDisplayingExpandedViewState();
}

class _DP1NowDisplayingExpandedViewState
    extends State<DP1NowDisplayingExpandedView> {
  late final PlaylistDetailsBloc _playlistDetailsBloc;
  bool _isLoadingMore = false;
  int? _selectedIndex;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = PlaylistDetailsBloc(widget.playlist);
    _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
    _selectedIndex = widget.selectedIndex;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant DP1NowDisplayingExpandedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist != widget.playlist) {
      _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _selectedIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _playlistDetailsBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      final state = _playlistDetailsBloc.state;
      if (state.hasMore && state is! PlaylistDetailsLoadingMoreState) {
        _isLoadingMore = true;
        _playlistDetailsBloc.add(LoadMorePlaylistDetailsEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColor.white,
      child: BlocConsumer<PlaylistDetailsBloc, PlaylistDetailsState>(
        bloc: _playlistDetailsBloc,
        listener: (context, state) {
          if (state is! PlaylistDetailsLoadingMoreState) {
            _isLoadingMore = false;
          }
        },
        builder: (context, state) {
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 30, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('STUDIO',
                        style: theme.textTheme.ppMori400Black12
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    CustomPrimaryAsyncButton(
                      onTap: () {
                        injector<NavigationService>().navigateTo(
                          AppRouter.scanQRPage,
                          arguments: const ScanQRPagePayload(
                              scannerItem: ScannerItem.GLOBAL),
                        );
                      },
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/Add.svg',
                            width: 12,
                            height: 12,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Add FF1',
                            style: theme.textTheme.ppMori400Black12,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 11,
                      ),
                    )
                  ],
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollController,
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (state is PlaylistDetailsInitialState ||
                              state is PlaylistDetailsLoadingState)
                            SliverToBoxAdapter(
                              child: _loadingView(context),
                            )
                          else if (state.assetTokens.isEmpty)
                            SliverToBoxAdapter(
                              child: _emptyView(context),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final assetToken = state.assetTokens[index];
                                  final shouldBlur = _selectedIndex != null &&
                                      _selectedIndex != index;
                                  return Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          NowDisplayingTokenItemView(
                                            assetToken: assetToken,
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                      if (shouldBlur)
                                        Positioned.fill(
                                          child: Container(
                                            color:
                                                AppColor.white.withOpacity(0.5),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                                childCount: state.assetTokens.length,
                              ),
                            ),
                          if (state is PlaylistDetailsLoadingMoreState)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 24),
                                child: Center(
                                  child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _loadingView(BuildContext context) => Container(
        color: AppColor.white,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.paddingHorizontal,
          vertical: 60,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.paddingHorizontal,
        vertical: 60,
      ),
      child: Text('Playlist Empty', style: theme.textTheme.ppMori400White14),
    );
  }
}
