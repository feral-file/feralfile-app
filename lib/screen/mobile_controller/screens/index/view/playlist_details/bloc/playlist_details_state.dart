import 'package:autonomy_flutter/model/now_displaying_object.dart';

abstract class PlaylistDetailsState {
  const PlaylistDetailsState({
    required this.nowDisplayingItems,
    required this.hasMore,
    required this.currentPage,
  });
  final List<DP1NowDisplayingItem> nowDisplayingItems;
  final bool hasMore;
  final int currentPage;

  PlaylistDetailsState copyWith({
    List<DP1NowDisplayingItem>? nowDisplayingItems,
    bool? hasMore,
    int? currentPage,
  }) {
    return PlaylistDetailsLoadedState(
      nowDisplayingItems: nowDisplayingItems ?? this.nowDisplayingItems,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  List<Object?> get props => [nowDisplayingItems, hasMore, currentPage];
}

class PlaylistDetailsInitialState extends PlaylistDetailsState {
  const PlaylistDetailsInitialState()
      : super(
          nowDisplayingItems: const [],
          hasMore: true,
          currentPage: 0,
        );
}

class PlaylistDetailsLoadingState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.currentPage,
  });
}

class PlaylistDetailsLoadedState extends PlaylistDetailsState {
  const PlaylistDetailsLoadedState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.currentPage,
  });
}

class PlaylistDetailsLoadingMoreState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingMoreState({
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.currentPage,
  });
}

class PlaylistDetailsErrorState extends PlaylistDetailsState {
  const PlaylistDetailsErrorState({
    required this.error,
    required super.nowDisplayingItems,
    required super.hasMore,
    required super.currentPage,
  });
  final String error;

  @override
  List<Object?> get props => super.props..add(error);
}
