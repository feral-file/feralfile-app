import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/service/dp1_playlist_service.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_mobile_controller.dart';

class MockPlaylistsBloc extends PlaylistsBloc {
  MockPlaylistsBloc({required DP1FeedService playlistService})
      : super(playlistService: playlistService);

  @override
  void add(PlaylistsEvent event) {
    if (event is LoadPlaylistsEvent) {
      // Use shared mock data
      emit(PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: MockMobileControllerData.mockPlaylists,
        hasMore: false,
        cursor: null,
        error: null,
      ));
    } else if (event is LoadMorePlaylistsEvent) {
      // Mock load more playlists
      final currentState = state;
      final additionalPlaylists = [
        DP1Call(
          dpVersion: '1.0.0',
          id: 'mock-playlist-4',
          slug: 'mock-playlist-4',
          title: 'Mock Playlist 4',
          created: DateTime.now().subtract(const Duration(days: 4)),
          defaults: {'display': {}},
          items: [
            DP1Item(
              duration: 90,
              provenance: DP1Provenance(
                type: DP1ProvenanceType.onChain,
                contract: DP1Contract(
                  chain: DP1ProvenanceChain.evm,
                  standard: DP1ProvenanceStandard.erc721,
                  address: '0x1234567890123456789012345678901234567890',
                  tokenId: '4',
                ),
              ),
              title: 'Mock Artwork 4',
              source: 'https://example.com/mock-image-4.jpg',
            ),
          ],
          signature: 'mock-signature-4',
        ),
      ];

      emit(currentState.copyWith(
        playlists: [...currentState.playlists, ...additionalPlaylists],
        status: PlaylistsStateStatus.loaded,
        hasMore: false,
      ));
    } else if (event is RefreshPlaylistsEvent) {
      // Mock refresh playlists
      final mockPlaylists = [
        DP1Call(
          dpVersion: '1.0.0',
          id: 'mock-refresh-playlist-1',
          slug: 'mock-refresh-playlist-1',
          title: 'Mock Refresh Playlist 1',
          created: DateTime.now(),
          defaults: {'display': {}},
          items: [
            DP1Item(
              duration: 30,
              provenance: DP1Provenance(
                type: DP1ProvenanceType.onChain,
                contract: DP1Contract(
                  chain: DP1ProvenanceChain.evm,
                  standard: DP1ProvenanceStandard.erc721,
                  address: '0x1234567890123456789012345678901234567890',
                  tokenId: '5',
                ),
              ),
              title: 'Mock Refresh Artwork 1',
              source: 'https://example.com/mock-refresh-image-1.jpg',
            ),
          ],
          signature: 'mock-refresh-signature-1',
        ),
      ];

      emit(PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: mockPlaylists,
        hasMore: false,
        cursor: null,
        error: null,
      ));
    } else {
      super.add(event);
    }
  }
}
