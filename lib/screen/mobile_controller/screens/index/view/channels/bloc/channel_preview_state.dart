part of 'channel_preview_bloc.dart';

abstract class ChannelPreviewState {
  const ChannelPreviewState({
    required this.channelReference,
    required this.creator,
    required this.items,
    required this.currentItemsPage,
    required this.hasMoreItems,
    required this.isLoadingMore,
  });

  final ChannelReference channelReference;
  final String creator;
  final List<DP1NowDisplayingItem> items;
  final int currentItemsPage;
  final bool hasMoreItems;
  final bool isLoadingMore;

  ChannelPreviewState copyWith({
    ChannelReference? channelReference,
    String? creator,
    List<DP1NowDisplayingItem>? items,
    int? currentItemsPage,
    bool? hasMoreItems,
    bool? isLoadingMore,
  }) {
    return ChannelPreviewLoadedState(
      channelReference: channelReference ?? this.channelReference,
      creator: creator ?? this.creator,
      items: items ?? this.items,
      currentItemsPage: currentItemsPage ?? this.currentItemsPage,
      hasMoreItems: hasMoreItems ?? this.hasMoreItems,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ChannelPreviewInitialState extends ChannelPreviewState {
  ChannelPreviewInitialState({
    required super.channelReference,
  }) : super(
          creator: '',
          items: const [],
          currentItemsPage: 0,
          hasMoreItems: true,
          isLoadingMore: false,
        );
}

class ChannelPreviewLoadingState extends ChannelPreviewState {
  const ChannelPreviewLoadingState({
    required super.channelReference,
    required super.creator,
    required super.items,
    required super.currentItemsPage,
    required super.hasMoreItems,
    required super.isLoadingMore,
  });
}

class ChannelPreviewLoadedState extends ChannelPreviewState {
  const ChannelPreviewLoadedState({
    required super.channelReference,
    required super.creator,
    required super.items,
    required super.currentItemsPage,
    required super.hasMoreItems,
    required super.isLoadingMore,
  });
}

class ChannelPreviewLoadingMoreState extends ChannelPreviewState {
  const ChannelPreviewLoadingMoreState({
    required super.channelReference,
    required super.creator,
    required super.items,
    required super.currentItemsPage,
    required super.hasMoreItems,
    required super.isLoadingMore,
  });
}

class ChannelPreviewErrorState extends ChannelPreviewState {
  const ChannelPreviewErrorState({
    required this.error,
    required super.channelReference,
    required super.creator,
    required super.items,
    required super.currentItemsPage,
    required super.hasMoreItems,
    required super.isLoadingMore,
  });

  final String error;
}


