import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:equatable/equatable.dart';
import 'error.dart';

enum AddLocalFeedServerStatus {
  initial,
  loading,
  loaded,
  error,
  adding,
  added,
}

class AddLocalFeedServerState extends Equatable {
  const AddLocalFeedServerState({
    this.status = AddLocalFeedServerStatus.initial,
    this.playlists = const [],
    this.serverUrl,
    this.error,
  });

  final AddLocalFeedServerStatus status;
  final List<DP1Call> playlists;
  final String? serverUrl;
  final AddLocalFeedServerError? error;

  bool get isInitial => status == AddLocalFeedServerStatus.initial;
  bool get isLoading => status == AddLocalFeedServerStatus.loading;
  bool get isLoaded => status == AddLocalFeedServerStatus.loaded;
  bool get isError => status == AddLocalFeedServerStatus.error;
  bool get isAdding => status == AddLocalFeedServerStatus.adding;
  bool get isAdded => status == AddLocalFeedServerStatus.added;

  bool get hasPlaylists => playlists.isNotEmpty;
  bool get hasError => error != null;

  AddLocalFeedServerState copyWith({
    AddLocalFeedServerStatus? status,
    List<DP1Call>? playlists,
    String? serverUrl,
    AddLocalFeedServerError? error,
  }) {
    return AddLocalFeedServerState(
      status: status ?? this.status,
      playlists: playlists ?? this.playlists,
      serverUrl: serverUrl ?? this.serverUrl,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, playlists, serverUrl, error];
}
