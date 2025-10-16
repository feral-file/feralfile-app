import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_event.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_state.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/error.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:bloc/bloc.dart';

class AddLocalFeedServerBloc
    extends AuBloc<AddLocalFeedServerEvent, AddLocalFeedServerState> {
  AddLocalFeedServerBloc() : super(const AddLocalFeedServerState()) {
    on<LoadPlaylistsEvent>(_onLoadPlaylists);
    on<LoadMorePlaylistsEvent>(_onLoadMorePlaylists);
    on<AddServerEvent>(_onAddServer);
    on<ClearErrorEvent>(_onClearError);
    on<ResetEvent>(_onReset);
  }

  // Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Future<void> _onLoadPlaylists(
    LoadPlaylistsEvent event,
    Emitter<AddLocalFeedServerState> emit,
  ) async {
    final url = event.url.trim();

    // Validate URL
    if (url.isEmpty) {
      emit(state.copyWith(
        status: AddLocalFeedServerStatus.error,
        error: UrlEmptyError(),
      ));
      return;
    }

    if (!_isValidUrl(url)) {
      emit(state.copyWith(
        status: AddLocalFeedServerStatus.error,
        error: UrlInvalidError(),
      ));
      return;
    }

    // Check if server already exists
    final feedManager = injector<FeralFileFeedManager>();
    if (feedManager.isFeedServiceExists(url)) {
      emit(state.copyWith(
        status: AddLocalFeedServerStatus.error,
        error: UrlAlreadyAddedError(),
      ));
      return;
    }

    emit(state.copyWith(
      status: AddLocalFeedServerStatus.loading,
      error: null,
      playlists: [],
      serverUrl: url,
    ));

    try {
      // Create a temporary feed service to test the connection
      final tempService = BaseDP1FeedServiceImpl(baseUrl: url);
      await tempService.init();

      final response = await _loadPlaylists(
          emit: emit, tempService: tempService, cursor: null);

      log.info(
          'Successfully loaded ${response.items.length} playlists from $url');
    } catch (e) {
      AddLocalFeedServerError error;
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('TimeoutException')) {
        error = CannotConnectError();
      } else if (msg.contains('FormatException')) {
        error = InvalidResponseError();
      } else if (msg.contains('404')) {
        error = NotFoundError();
      } else if (msg.contains('403')) {
        error = AccessDeniedError();
      } else if (msg.contains('500')) {
        error = ServerError();
      } else {
        error = LoadPlaylistsFailedError(msg);
      }

      emit(state.copyWith(
        status: AddLocalFeedServerStatus.error,
        error: error,
      ));

      log.info('Error loading playlists from $url: $e');
    }
  }

  Future<void> _onLoadMorePlaylists(
    LoadMorePlaylistsEvent event,
    Emitter<AddLocalFeedServerState> emit,
  ) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    emit(state.copyWith(status: AddLocalFeedServerStatus.loadingMore));

    final tempService = BaseDP1FeedServiceImpl(baseUrl: state.serverUrl!);
    await tempService.init();
    await _loadPlaylists(
        emit: emit, tempService: tempService, cursor: state.cursor);
  }

  Future<DP1PlaylistResponse> _loadPlaylists({
    required Emitter<AddLocalFeedServerState> emit,
    required BaseDP1FeedServiceImpl tempService,
    required String? cursor,
  }) async {
    final response = await tempService.getPlaylists(limit: 20, cursor: cursor);
    final newPlaylists = [...state.playlists, ...response.items];
    emit(state.copyWith(
      status: AddLocalFeedServerStatus.loaded,
      playlists: newPlaylists,
      hasMore: response.hasMore,
      cursor: response.cursor,
    ));
    return response;
  }

  Future<void> _onAddServer(
    AddServerEvent event,
    Emitter<AddLocalFeedServerState> emit,
  ) async {
    if (state.serverUrl == null) return;

    emit(state.copyWith(
      status: AddLocalFeedServerStatus.adding,
    ));

    try {
      final feedManager = injector<FeralFileFeedManager>();

      // Double-check if server already exists
      if (feedManager.isFeedServiceExists(state.serverUrl!)) {
        emit(state.copyWith(
          status: AddLocalFeedServerStatus.error,
          error: UrlAlreadyAddedError(),
        ));
        return;
      }

      // Create and add the feed service
      final feedService = BaseDP1FeedServiceImpl(
          baseUrl: state.serverUrl!, isExternalFeedService: true);
      await feedService.init();
      await feedManager.addCustomFeedServices([feedService]);

      emit(state.copyWith(
        status: AddLocalFeedServerStatus.added,
      ));

      log.info('Successfully added server: ${state.serverUrl}');
    } catch (e) {
      emit(state.copyWith(
        status: AddLocalFeedServerStatus.error,
        error: AddServerFailedError(e.toString()),
      ));
      log.info('Error adding server to FeedManager: $e');
    }
  }

  void _onClearError(
    ClearErrorEvent event,
    Emitter<AddLocalFeedServerState> emit,
  ) {
    emit(state.copyWith(
      error: null,
    ));
  }

  void _onReset(
    ResetEvent event,
    Emitter<AddLocalFeedServerState> emit,
  ) {
    emit(const AddLocalFeedServerState());
  }
}
