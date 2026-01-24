import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/ArtworkItem.dart';
import 'package:autonomy_flutter/design/build/components/DP1Carousel.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/artwork_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/service/thumbnail_prefetch_service.dart';
import 'package:autonomy_flutter/util/debouce_util.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/util/thumbnail_url_parser.dart';
import 'package:flutter/material.dart';

/// DP1 Carousel - Horizontal scrollable carousel for displaying DP1 items
class DP1Carousel extends StatefulWidget {
  const DP1Carousel({
    required this.items,
    this.onItemTap,
    this.scrollController,
    this.isLoadingMore = false,
    this.onLoadMore,
    super.key,
  });

  final List<DP1NowDisplayingItem> items;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  @override
  State<DP1Carousel> createState() => _DP1CarouselState();
}

class _DP1CarouselState extends State<DP1Carousel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);

    // Prefetch initial visible items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePrefetchWindow();
    });
  }

  @override
  void didUpdateWidget(DP1Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      // Items changed, update prefetch window
      _updatePrefetchWindow();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Update prefetch window
    try {
      withDebounce(
        _updatePrefetchWindow,
        key: 'carousel_prefetch_${hashCode}',
        debounceTime: 200,
      );
    } catch (e) {
      // Debounce blocked - skip
    }

    // Trigger onLoadMore when scrolled to 80% of the carousel
    if (currentScroll >= maxScroll * 0.8 && !widget.isLoadingMore) {
      try {
        withDebounce(
          () => widget.onLoadMore?.call(),
          key: 'carousel_load_more_${hashCode}',
          debounceTime: 300,
        );
      } catch (e) {
        // Debounce blocked - do nothing, already loading
      }
    }
  }

  /// Update prefetch window based on scroll position
  void _updatePrefetchWindow() {
    if (!mounted || widget.items.isEmpty) {
      return;
    }

    try {
      // Calculate visible range based on scroll position
      final scrollOffset = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;
      final viewportWidth = _scrollController.hasClients
          ? _scrollController.position.viewportDimension
          : 0.0;

      // Item extent (width + padding)
      const itemExtent = ArtworkItemTokens.containerWidth +
          DP1CarouselTokens.contentPaddingHorizontal;

      // Calculate indices
      final firstVisibleIndex = (scrollOffset / itemExtent).floor();
      final visibleCount = (viewportWidth / itemExtent).ceil() + 1;
      final lastVisibleIndex = firstVisibleIndex + visibleCount;

      // Prefetch window: visible + ahead + a bit behind
      const aheadMultiplier = 2; // Prefetch 2x viewport ahead
      const behindMultiplier = 1; // Keep 1x viewport behind

      final startIndex = (firstVisibleIndex - (visibleCount * behindMultiplier))
          .clamp(0, widget.items.length);
      final endIndex = (lastVisibleIndex + (visibleCount * aheadMultiplier))
          .clamp(0, widget.items.length);

      // Build set of keys to prefetch
      final keysToWarm = <String>{};
      for (var i = startIndex; i < endIndex; i++) {
        final item = widget.items[i];
        final thumbnailUri = item.thumbnail?.uri;
        if (thumbnailUri != null && thumbnailUri.isNotEmpty) {
          final parsed = ThumbnailUrlParser.parse(thumbnailUri);

          // Only select variants for Cloudflare URLs
          final isCloudflareUrl = thumbnailUri.contains('imagedelivery.net');
          
          String variant;
          if (isCloudflareUrl) {
            // For carousel thumbnails, use appropriate variant based on container size
            // Use width for selection, aspect ratio will be maintained
            final targetWidthPx = ArtworkItemTokens.imageWidth.toInt();

            variant = ThumbnailUrlParser.selectVariantForSize(
              widthPx: targetWidthPx,
              heightPx: targetWidthPx,
            );
          } else {
            // Non-Cloudflare URLs use 'original' variant
            variant = parsed.variant;
          }

          final key = '${parsed.originKey}|$variant';
          keysToWarm.add(key);
        }
      }

      // Determine priority based on position
      PrefetchPriority priority = PrefetchPriority.ahead;
      if (firstVisibleIndex <= startIndex && endIndex <= lastVisibleIndex) {
        priority = PrefetchPriority.visible;
      }

      // Update prefetch service
      // Only pass width - height will be calculated to maintain aspect ratio
      final prefetchService = injector<ThumbnailPrefetchService>();
      prefetchService.setDesiredWindow(
        keysToWarm,
        priority,
        targetSize: ThumbnailSize(
          widthPx: ArtworkItemTokens.imageWidth.toInt(),
          heightPx: 0, // 0 = maintain aspect ratio
        ),
      );
    } catch (e) {
      // Silently fail - don't crash the carousel
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DP1CarouselTokens.itemHeight,
      child: CustomScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: DP1CarouselTokens.contentPaddingHorizontal,
              vertical: DP1CarouselTokens.contentPaddingVertical,
            ),
            sliver: SliverList.builder(
              itemCount: widget.items.length,
              itemBuilder: (context, index) => DP1ItemThumbnail(
                item: widget.items[index],
                onTap: () {
                  widget.onItemTap?.call(widget.items[index]);
                },
              ),
            ),
          ),
          if (widget.isLoadingMore)
            SliverPadding(
              padding: const EdgeInsets.only(right: 12),
              sliver: SliverToBoxAdapter(
                child: LoadMoreIndicator(
                  isLoadingMore: widget.isLoadingMore,
                  padding: EdgeInsets.zero,
                  showText: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
