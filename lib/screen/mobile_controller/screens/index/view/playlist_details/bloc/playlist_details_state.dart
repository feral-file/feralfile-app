import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';

abstract class PlaylistDetailsState {
  const PlaylistDetailsState({
    required this.nowDisplayingItems,
    required this.hasMore,
    required this.offset,
    this.total,
    this.channelReference,
  });
  final List<DP1NowDisplayingItem> nowDisplayingItems;
  final bool hasMore;
  final int offset;
  final int? total;
  final ChannelReference? channelReference;

  PlaylistDetailsState copyWith({
    List<DP1NowDisplayingItem>? nowDisplayingItems,
    bool? hasMore,
    int? offset,
    int? total,
    ChannelReference? channelReference,
  }) {
    return PlaylistDetailsLoadedState(
      nowDisplayingItems: nowDisplayingItems ?? this.nowDisplayingItems,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      total: total ?? this.total,
      channelReference: channelReference ?? this.channelReference,
    );
  }

  List<Object?> get props => [nowDisplayingItems, hasMore, offset, total];
}

class PlaylistDetailsInitialState extends PlaylistDetailsState {
  const PlaylistDetailsInitialState()
      : super(
          nowDisplayingItems: const [],
          hasMore: true,
          offset: 0,
          total: null,
        );
}

class PlaylistDetailsLoadingState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
    super.total,
  });
}

class PlaylistDetailsLoadedState extends PlaylistDetailsState {
  const PlaylistDetailsLoadedState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
    super.total,
    super.channelReference,
  });
}

class PlaylistDetailsLoadingMoreState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingMoreState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
    super.total,
    super.channelReference,
  });
}

class PlaylistDetailsErrorState extends PlaylistDetailsState {
  const PlaylistDetailsErrorState({
    required this.error,
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
    super.total,
    super.channelReference,
  });
  final String error;

  @override
  List<Object?> get props => super.props..add(error);
}
