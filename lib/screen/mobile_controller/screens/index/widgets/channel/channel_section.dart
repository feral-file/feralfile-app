import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel/channel_list_row.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel/channel_section_header.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';

/// Channel Section - Combines header with list of channel rows
class ChannelSection extends StatelessWidget {
  const ChannelSection({
    required this.sectionName,
    required this.channels,
    this.sectionIcon,
    this.onViewAllTap,
    this.onChannelItemTap,
    this.scrollController,
    this.hasMore = true,
    this.onLoadMore,
    super.key,
  });

  final String sectionName;
  final List<ChannelData> channels;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;
  final void Function(DP1NowDisplayingItem)? onChannelItemTap;
  final ScrollController? scrollController;
  final bool hasMore;
  final void Function(ChannelData)? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: channels.length + 2,
      itemBuilder: (context, index) {
        // Header
        if (index == 0) {
          return ChannelSectionHeader(
            sectionName: sectionName,
            sectionIcon: sectionIcon,
            onViewAllTap: hasMore ? onViewAllTap : null,
            hasMore: hasMore,
          );
        }

        // Gap
        if (index == 1) {
          return const SizedBox(
            height: 10,
          );
        }

        // List items
        final channelIndex = index - 2;
        final channel = channels[channelIndex];
        return ChannelListRow(
          channelReference: channel.channelReference,
          channelCreator: channel.creator,
          carouselItems: channel.items,
          onItemTap: onChannelItemTap,
          scrollController: scrollController,
          isLoadingMore: channel.isLoadingMore,
          onLoadMore: () {
            onLoadMore?.call(channel);
          },
        );
      },
    );
  }
}

/// Data model for channel information
class ChannelData {
  ChannelData({
    required this.channelReference,
    required this.creator,
    required this.items,
    this.currentItemsPage = 0,
    this.hasMoreItems = false,
    this.isLoadingMore = false,
  });

  final ChannelReference channelReference;
  final String creator;
  final List<DP1NowDisplayingItem> items;
  final int currentItemsPage;
  final bool hasMoreItems;
  final bool isLoadingMore;
  ChannelData copyWith({
    ChannelReference? channelReference,
    String? creator,
    List<DP1NowDisplayingItem>? items,
    int? currentItemsPage,
    bool? hasMoreItems,
    bool? isLoadingMore,
  }) {
    return ChannelData(
      channelReference: channelReference ?? this.channelReference,
      creator: creator ?? this.creator,
      items: items ?? this.items,
      currentItemsPage: currentItemsPage ?? this.currentItemsPage,
      hasMoreItems: hasMoreItems ?? this.hasMoreItems,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelData &&
        channelReference == other.channelReference &&
        creator == other.creator &&
        items == other.items &&
        currentItemsPage == other.currentItemsPage &&
        hasMoreItems == other.hasMoreItems &&
        isLoadingMore == other.isLoadingMore;
  }

  @override
  int get hashCode => Object.hash(channelReference, creator, items,
      currentItemsPage, hasMoreItems, isLoadingMore);
}
