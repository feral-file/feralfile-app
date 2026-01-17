import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channel_preview_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channel_preview_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/dp1_carousel.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Channel List Row - Combines list item info with carousel content
class ChannelListRow extends StatefulWidget {
  const ChannelListRow({
    required this.channelReference,
    this.onItemTap,
    this.scrollController,
    super.key,
  });

  final ChannelReference channelReference;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;

  @override
  State<ChannelListRow> createState() => _ChannelListRowState();
}

class _ChannelListRowState extends State<ChannelListRow> {
  late ChannelPreviewBloc _channelPreviewBloc;

  @override
  void initState() {
    super.initState();
    _channelPreviewBloc = injector<ChannelPreviewBlocManager>().getBloc(
      channelReference: widget.channelReference,
      channelItemsPageSize: 10,
    );
  }

  @override
  void didUpdateWidget(ChannelListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelReference != widget.channelReference) {
      injector<ChannelPreviewBlocManager>()
          .releaseBlocByInstance(_channelPreviewBloc);
      setState(() {
        _channelPreviewBloc = injector<ChannelPreviewBlocManager>().getBloc(
          channelReference: widget.channelReference,
          channelItemsPageSize: 10,
        );
      });
    }
  }

  @override
  void dispose() {
    injector<ChannelPreviewBlocManager>()
        .releaseBlocByInstance(_channelPreviewBloc);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChannelPreviewBloc, ChannelPreviewState>(
      bloc: _channelPreviewBloc,
      builder: (context, previewState) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRouter.channelDetailPage,
              arguments: ChannelDetailPagePayload(
                channelReference: widget.channelReference,
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
                ChannelHeader(
                  channelReference: widget.channelReference,
                  maxLines: 4,
                ),
                DP1Carousel(
                  items: previewState.items,
                  onItemTap: widget.onItemTap,
                  scrollController: widget.scrollController,
                  isLoadingMore: previewState.isLoadingMore,
                  onLoadMore: () {
                    _channelPreviewBloc
                        .add(const LoadMoreChannelPreviewItemsEvent());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
