part of 'channels_bloc.dart';

enum ChannelsStateStatus {
  initial,
  loading,
  loadingMore,
  loaded,
  error,
}

@immutable
class ChannelsState {
  const ChannelsState({
    this.status = ChannelsStateStatus.initial,
    this.channelReferences = const [],
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final ChannelsStateStatus status;
  final bool hasMore;
  final List<ChannelReference> channelReferences;
  final String? cursor;
  final String? error;

  ChannelsState copyWith({
    ChannelsStateStatus? status,
    List<ChannelReference>? channelReferences,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return ChannelsState(
      status: status ?? this.status,
      channelReferences: channelReferences ?? this.channelReferences,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChannelsState &&
        other.status == status &&
        other.channelReferences == channelReferences &&
        other.hasMore == hasMore &&
        other.cursor == cursor &&
        other.error == error;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        channelReferences.hashCode ^
        hasMore.hashCode ^
        cursor.hashCode ^
        error.hashCode;
  }

  bool get isInitial => status == ChannelsStateStatus.initial;
  bool get isLoading => status == ChannelsStateStatus.loading;
  bool get isLoadingMore => status == ChannelsStateStatus.loadingMore;
  bool get isLoaded => status == ChannelsStateStatus.loaded;
  bool get isError => status == ChannelsStateStatus.error;
}
