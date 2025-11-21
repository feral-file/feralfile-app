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
    super.key,
  });

  final String sectionName;
  final List<ChannelData> channels;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;
  final void Function(DP1NowDisplayingItem)? onChannelItemTap;
  final ScrollController? scrollController;
  final bool hasMore;

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
  });

  final ChannelReference channelReference;
  final String creator;
  final List<DP1NowDisplayingItem> items;

  ChannelData copyWith({
    ChannelReference? channelReference,
    String? creator,
    List<DP1NowDisplayingItem>? items,
  }) {
    return ChannelData(
      channelReference: channelReference ?? this.channelReference,
      creator: creator ?? this.creator,
      items: items ?? this.items,
    );
  }
}
