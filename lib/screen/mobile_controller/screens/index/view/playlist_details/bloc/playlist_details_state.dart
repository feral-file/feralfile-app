import 'package:autonomy_flutter/model/now_displaying_object.dart';

abstract class PlaylistDetailsState {
  const PlaylistDetailsState({
    required this.nowDisplayingItems,
    required this.hasMore,
    required this.offset,
  });
  final List<DP1NowDisplayingItem> nowDisplayingItems;
  final bool hasMore;
  final int offset;

  PlaylistDetailsState copyWith({
    List<DP1NowDisplayingItem>? nowDisplayingItems,
    bool? hasMore,
    int? offset,
  }) {
    return PlaylistDetailsLoadedState(
      nowDisplayingItems: nowDisplayingItems ?? this.nowDisplayingItems,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
    );
  }

  List<Object?> get props => [nowDisplayingItems, hasMore, offset];
}

class PlaylistDetailsInitialState extends PlaylistDetailsState {
  const PlaylistDetailsInitialState()
      : super(
          nowDisplayingItems: const [],
          hasMore: true,
          offset: 0,
        );
}

class PlaylistDetailsLoadingState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
  });
}

class PlaylistDetailsLoadedState extends PlaylistDetailsState {
  const PlaylistDetailsLoadedState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
  });
}

class PlaylistDetailsLoadingMoreState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingMoreState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
  });
}

class PlaylistDetailsErrorState extends PlaylistDetailsState {
  const PlaylistDetailsErrorState({
    required this.error,
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.offset,
  });
  final String error;

  @override
  List<Object?> get props => super.props..add(error);
}
