import 'package:autonomy_flutter/design/build/components/DP1Carousel.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/artwork_item.dart';
import 'package:flutter/material.dart';

/// DP1 Carousel - Horizontal scrollable carousel for displaying DP1 items
class DP1Carousel extends StatelessWidget {
  const DP1Carousel({
    required this.items,
    this.onItemTap,
    this.scrollController,
    super.key,
  });

  final List<DP1NowDisplayingItem> items;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const PageScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DP1CarouselTokens.contentPaddingHorizontal,
          vertical: DP1CarouselTokens.contentPaddingVertical,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            items.length,
            (index) => DP1ItemThumbnail(
              item: items[index],
              onTap: () {
                onItemTap?.call(items[index]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
