class AddLocalFeedServerError extends Error {
  String get message => 'AddLocalFeedServerError';
}

class UrlEmptyError extends AddLocalFeedServerError {
  @override
  String get message => 'Please enter a URL';
}

class UrlInvalidError extends AddLocalFeedServerError {
  @override
  String get message => 'Please enter a valid URL (http:// or https://)';
}

class UrlAlreadyAddedError extends AddLocalFeedServerError {
  @override
  String get message => 'This server is already added to Feral File';
}

class CannotConnectError extends AddLocalFeedServerError {
  @override
  String get message =>
      'Cannot connect to server. Please check the URL and try again.';
}

class InvalidResponseError extends AddLocalFeedServerError {
  @override
  String get message =>
      'Invalid server response format. This may not be a valid DP1 server.';
}

class NotFoundError extends AddLocalFeedServerError {
  @override
  String get message => 'Server not found. Please check the URL.';
}

class AccessDeniedError extends AddLocalFeedServerError {
  @override
  String get message => 'Access denied. The server may require authentication.';
}

class ServerError extends AddLocalFeedServerError {
  @override
  String get message => 'Server error. Please try again later.';
}

class LoadPlaylistsFailedError extends AddLocalFeedServerError {
  LoadPlaylistsFailedError(this.rawMessage);
  final String rawMessage;

  @override
  String get message => 'Failed to load playlists: $rawMessage';
}

class AddServerFailedError extends AddLocalFeedServerError {
  AddServerFailedError(this.rawMessage);
  final String rawMessage;

  @override
  String get message => 'Failed to add server: $rawMessage';
}
