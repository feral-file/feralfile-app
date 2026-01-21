import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/service/thumbnail_prefetch_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/thumbnail_url_parser.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistAssetGridView extends StatefulWidget {
  const PlaylistAssetGridView({
    required this.playlist,
    super.key,
    this.header,
    this.backgroundColor = AppColor.auGreyBackground,
    this.physics,
    this.showLoadingOnUpdating = true,
  });

  final DP1Call playlist;
  final Widget? header;
  final Color backgroundColor;
  final ScrollPhysics? physics;
  final bool showLoadingOnUpdating;

  @override
  State<PlaylistAssetGridView> createState() => _PlaylistAssetGridViewState();
}

class _PlaylistAssetGridViewState extends State<PlaylistAssetGridView> {
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;

  late PlaylistDetailsBloc _playlistDetailsBloc;

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc =
        injector<PlaylistDetailsBlocManager>().getBloc(widget.playlist);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Prefetch initial visible items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePrefetchWindow();
    });
  }

  @override
  void didUpdateWidget(covariant PlaylistAssetGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.playlist.isItemsEqual(widget.playlist)) {
      // Release old bloc and get new bloc for the new playlist
      injector<PlaylistDetailsBlocManager>()
          .releaseBlocByInstance(_playlistDetailsBloc);
      // Force rebuild with new bloc
      setState(() {
        _playlistDetailsBloc =
            injector<PlaylistDetailsBlocManager>().getBloc(widget.playlist);
      });
    } else {
      log.info('PlaylistAssetGridView: didUpdateWidget no need to update');
    }
  }

  @override
  void dispose() {
    injector<PlaylistDetailsBlocManager>()
        .releaseBlocByInstance(_playlistDetailsBloc);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Update prefetch window (debounced)
    _updatePrefetchWindow();

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

  /// Update prefetch window based on scroll position
  void _updatePrefetchWindow() {
    if (!mounted) {
      return;
    }

    try {
      final state = _playlistDetailsBloc.state;
      final items = state.nowDisplayingItems;
      if (items.isEmpty) {
        return;
      }

      // Calculate grid dimensions
      const crossAxisCount =
          2; // From SliverGridDelegateWithFixedCrossAxisCount
      const childAspectRatio = 188 / 307;

      final scrollOffset = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;
      final viewportHeight = _scrollController.hasClients
          ? _scrollController.position.viewportDimension
          : 0.0;

      // Estimate row height from viewport width
      final viewportWidth = MediaQuery.of(context).size.width;
      final itemWidth =
          (viewportWidth - ResponsiveLayout.paddingHorizontal * 2 - 17) / 2;
      final itemHeight = itemWidth / childAspectRatio;

      // Calculate visible rows
      final firstVisibleRow = (scrollOffset / itemHeight).floor();
      final visibleRows = (viewportHeight / itemHeight).ceil() + 1;
      final lastVisibleRow = firstVisibleRow + visibleRows;

      // Prefetch window: visible + ahead rows + behind rows
      const aheadRows = 4; // Prefetch 4 rows ahead
      const behindRows = 2; // Keep 2 rows behind

      final startRow = (firstVisibleRow - behindRows)
          .clamp(0, items.length ~/ crossAxisCount);
      final endRow = (lastVisibleRow + aheadRows)
          .clamp(0, (items.length + crossAxisCount - 1) ~/ crossAxisCount);

      final startIndex = startRow * crossAxisCount;
      final endIndex = (endRow * crossAxisCount).clamp(0, items.length);

      // Build set of keys to prefetch
      final keysToWarm = <String>{};
      for (var i = startIndex; i < endIndex; i++) {
        final item = items[i];
        final thumbnailUri = item.thumbnail?.uri;
        if (thumbnailUri != null && thumbnailUri.isNotEmpty) {
          final parsed = ThumbnailUrlParser.parse(thumbnailUri);

          // Only select variants for Cloudflare URLs
          final isCloudflareUrl = thumbnailUri.contains('imagedelivery.net');
          
          String variant;
          if (isCloudflareUrl) {
            // For grid thumbnails, determine variant based on item size
            final targetSize = ThumbnailSize(
              widthPx:
                  (itemWidth * MediaQuery.of(context).devicePixelRatio).toInt(),
              heightPx:
                  (itemHeight * MediaQuery.of(context).devicePixelRatio).toInt(),
            );

            variant = ThumbnailUrlParser.selectVariantForSize(
              widthPx: targetSize.widthPx,
              heightPx: targetSize.heightPx,
            );
          } else {
            // Non-Cloudflare URLs use 'original' variant
            variant = parsed.variant;
          }

          final key = '${parsed.originKey}|$variant';
          keysToWarm.add(key);
        }
      }

      // Determine priority
      PrefetchPriority priority = PrefetchPriority.ahead;
      if (startIndex >= firstVisibleRow * crossAxisCount &&
          endIndex <= lastVisibleRow * crossAxisCount) {
        priority = PrefetchPriority.visible;
      }

      // Update prefetch service
      final prefetchService = injector<ThumbnailPrefetchService>();
      prefetchService.setDesiredWindow(
        keysToWarm,
        priority,
        targetSize: ThumbnailSize(
          widthPx:
              (itemWidth * MediaQuery.of(context).devicePixelRatio).toInt(),
          heightPx:
              (itemHeight * MediaQuery.of(context).devicePixelRatio).toInt(),
        ),
      );
    } catch (e) {
      log.info('[PlaylistAssetGridView] Error updating prefetch window: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlaylistDetailsBloc, PlaylistDetailsState>(
      key: ValueKey(_playlistDetailsBloc.hashCode),
      bloc: _playlistDetailsBloc,
      listener: (context, state) {
        if (state is! PlaylistDetailsLoadingMoreState) {
          _isLoadingMore = false;
        }

        // Update prefetch window when items change
        if (state is PlaylistDetailsLoadedState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updatePrefetchWindow();
          });
        }
      },
      builder: (context, state) {
        return CustomScrollView(
          controller: _scrollController,
          shrinkWrap: true,
          physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
          cacheExtent: 1000, // Build items 1000px ahead for smoother scrolling
          slivers: [
            if (widget.header != null) ...[
              SliverToBoxAdapter(
                child: widget.header!,
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: UIConstants.detailPageHeaderPadding,
                ),
              ),
            ],
            if (state is PlaylistDetailsInitialState ||
                (state is PlaylistDetailsLoadingState &&
                    widget.showLoadingOnUpdating))
              SliverToBoxAdapter(
                child: _loadingView(context),
              )
            else if (state.nowDisplayingItems.isEmpty &&
                state is! PlaylistDetailsLoadingMoreState)
              SliverToBoxAdapter(
                child: _emptyView(context),
              )
            else
              UIHelper.dp1ItemSliverGrid(
                  context, state.nowDisplayingItems, widget.playlist.title),
            if (state is PlaylistDetailsLoadingMoreState)
              const SliverToBoxAdapter(
                child: LoadMoreIndicator(
                  isLoadingMore: true,
                ),
              ),
            const SliverToBoxAdapter(
              child: BottomSpacing(),
            ),
          ],
        );
      },
    );
  }

  Widget _loadingView(BuildContext context) => LoadingWidget(
        backgroundColor: widget.backgroundColor,
        isInfinitySize: false,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.paddingHorizontal,
          vertical: 60,
        ),
      );

  Widget _emptyView(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.paddingHorizontal,
        vertical: 60,
      ),
      child: Text('Playlist Empty', style: AppTypography.body(context).white),
    );
  }
}
