enum DP1ErrorCode {
  playlistNotFound,
  allOwnCollectionEmpty,
}

class DP1Error implements Exception {
  DP1Error({
    required this.message,
    required this.code,
  });

  final String message;
  final DP1ErrorCode code;
}

// DP1 Playlist Error
class DP1PlaylistError extends DP1Error {
  DP1PlaylistError({
    required super.message,
    required super.code,
  });
}

// All Own Collection Empty Error
class DP1AllOwnCollectionEmptyError extends DP1Error {
  DP1AllOwnCollectionEmptyError({
    required super.message,
  }) : super(code: DP1ErrorCode.allOwnCollectionEmpty);
}
