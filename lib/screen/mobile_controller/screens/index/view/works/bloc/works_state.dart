part of 'works_bloc.dart';

enum WorksStateStatus {
  initial,
  loading,
  loadingMore,
  loaded,
  error,
}

@immutable
class WorksState {
  const WorksState({
    this.status = WorksStateStatus.initial,
    this.nowDisplayingItems = const [],
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final WorksStateStatus status;
  final List<DP1NowDisplayingItem> nowDisplayingItems;
  final bool hasMore;
  final String? cursor;
  final String? error;

  WorksState copyWith({
    WorksStateStatus? status,
    List<DP1NowDisplayingItem>? nowDisplayingItems,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return WorksState(
      status: status ?? this.status,
      nowDisplayingItems: nowDisplayingItems ?? this.nowDisplayingItems,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorksState &&
        other.status == status &&
        other.nowDisplayingItems == nowDisplayingItems &&
        other.hasMore == hasMore &&
        other.cursor == cursor &&
        other.error == error;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        nowDisplayingItems.hashCode ^
        hasMore.hashCode ^
        cursor.hashCode ^
        error.hashCode;
  }

  bool get isInitial => status == WorksStateStatus.initial;
  bool get isLoading => status == WorksStateStatus.loading;
  bool get isLoadingMore => status == WorksStateStatus.loadingMore;
  bool get isLoaded => status == WorksStateStatus.loaded;
  bool get isError => status == WorksStateStatus.error;
}
