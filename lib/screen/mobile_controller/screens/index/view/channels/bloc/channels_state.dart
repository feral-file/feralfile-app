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
    this.channels = const [],
    this.channelData = const [],
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final ChannelsStateStatus status;
  final List<ChannelReference> channels;
  final List<ChannelData> channelData;
  final bool hasMore;
  final String? cursor;
  final String? error;

  /// Backward compatibility - alias for channels
  List<ChannelReference> get channelReferences => channels;

  ChannelsState copyWith({
    ChannelsStateStatus? status,
    List<ChannelReference>? channels,
    List<ChannelData>? channelData,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return ChannelsState(
      status: status ?? this.status,
      channels: channels ?? this.channels,
      channelData: channelData ?? this.channelData,
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
        other.channels == channels &&
        other.channelData == channelData &&
        other.hasMore == hasMore &&
        other.cursor == cursor &&
        other.error == error;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        channels.hashCode ^
        channelData.hashCode ^
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

class LoadChannelPaginationResponse {
  const LoadChannelPaginationResponse({
    required this.channels,
    required this.hasMore,
    required this.cursor,
  });

  final List<ChannelReference> channels;
  final bool hasMore;
  final String? cursor;
}
