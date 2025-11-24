import 'package:autonomy_flutter/design/build/components/DP1Carousel.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/artwork_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:flutter/material.dart';

/// DP1 Carousel - Horizontal scrollable carousel for displaying DP1 items
class DP1Carousel extends StatelessWidget {
  const DP1Carousel({
    required this.items,
    this.onItemTap,
    this.scrollController,
    this.isLoadingMore = false,
    super.key,
  });

  final List<DP1NowDisplayingItem> items;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DP1CarouselTokens.itemHeight,
      child: CustomScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: DP1CarouselTokens.contentPaddingHorizontal,
              vertical: DP1CarouselTokens.contentPaddingVertical,
            ),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => DP1ItemThumbnail(
                item: items[index],
                onTap: () {
                  onItemTap?.call(items[index]);
                },
              ),
            ),
          ),
          if (isLoadingMore)
            SliverPadding(
              padding: const EdgeInsets.only(right: 12),
              sliver: SliverToBoxAdapter(
                child: LoadMoreIndicator(
                  isLoadingMore: isLoadingMore,
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
