import 'package:autonomy_flutter/design/build/components/DP1Carousel.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/artwork_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/util/debouce_util.dart';
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
