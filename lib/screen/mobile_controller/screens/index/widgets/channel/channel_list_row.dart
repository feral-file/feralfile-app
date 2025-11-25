import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/dp1_carousel.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';

/// Channel List Row - Combines list item info with carousel content
class ChannelListRow extends StatelessWidget {
  const ChannelListRow({
    required this.channelReference,
    required this.carouselItems,
    this.channelCreator,
    this.onItemTap,
    this.isLoadingMore = false,
    this.scrollController,
    this.onLoadMore,
    super.key,
  });

  final ChannelReference channelReference;
  final List<DP1NowDisplayingItem> carouselItems;
  final String? channelCreator;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final bool isLoadingMore;
  final ScrollController? scrollController;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRouter.channelDetailPage,
          arguments: ChannelDetailPagePayload(
            channelReference: channelReference,
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChannelItem(
              channelReference: channelReference,
              maxLines: 4,
            ),
            DP1Carousel(
              items: carouselItems,
              onItemTap: onItemTap,
              scrollController: scrollController,
              isLoadingMore: isLoadingMore,
              onLoadMore: onLoadMore,
            ),
          ],
        ),
      ),
    );
  }
}
