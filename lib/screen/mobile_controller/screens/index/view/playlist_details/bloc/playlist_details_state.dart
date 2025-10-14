import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

abstract class PlaylistDetailsState {
  const PlaylistDetailsState({
    required this.dp1Items,
    required this.assetTokens,
    required this.hasMore,
    required this.currentPage,
  });
  final List<DP1Item> dp1Items;
  final List<AssetToken> assetTokens;
  final bool hasMore;
  final int currentPage;

  PlaylistDetailsState copyWith({
    List<DP1Item>? dp1Items,
    List<AssetToken>? assetTokens,
    bool? hasMore,
    int? currentPage,
  }) {
    return PlaylistDetailsLoadedState(
      dp1Items: dp1Items ?? this.dp1Items,
      assetTokens: assetTokens ?? this.assetTokens,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => [assetTokens, hasMore, currentPage];
}

class PlaylistDetailsInitialState extends PlaylistDetailsState {
  const PlaylistDetailsInitialState()
      : super(
          dp1Items: const [],
          assetTokens: const [],
          hasMore: true,
          currentPage: 0,
        );
}

class PlaylistDetailsLoadingState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingState({
    required super.dp1Items,
    required super.assetTokens,
    required super.hasMore,
    required super.currentPage,
  });
}

class PlaylistDetailsLoadedState extends PlaylistDetailsState {
  const PlaylistDetailsLoadedState({
    required super.dp1Items,
    required super.assetTokens,
    required super.hasMore,
    required super.currentPage,
  });
}

class PlaylistDetailsLoadingMoreState extends PlaylistDetailsState {
  const PlaylistDetailsLoadingMoreState({
    required super.dp1Items,
    required super.assetTokens,
    required super.hasMore,
    required super.currentPage,
  });
}

class PlaylistDetailsErrorState extends PlaylistDetailsState {
  const PlaylistDetailsErrorState({
    required this.error,
    required super.dp1Items,
    required super.assetTokens,
    required super.hasMore,
    required super.currentPage,
  });
  final String error;

  @override
  List<Object?> get props => super.props..add(error);
}
