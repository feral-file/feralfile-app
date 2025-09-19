import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';

class MockDp1PlaylistService extends DP1FeedService {
  MockDp1PlaylistService(super.api);

  @override
  Future<DP1Call> createPlaylist(
      {required DP1CreatePlaylistRequest request,
      bool isSyncToCloud = true}) async {
    // Mock creating a playlist: return a DP1Call-like object using provided data
    return DP1Call(
      dpVersion: request.dpVersion,
      id: 'mock-created-playlist-id',
      slug: 'mock-created-playlist',
      title: request.title,
      created: DateTime.now(),
      defaults: <String, dynamic>{'display': <String, dynamic>{}},
      items: request.items
          .map(
            (e) => DP1Item(
              duration: e.duration,
              provenance: e.provenance,
              title: e.title,
              source: e.source,
            ),
          )
          .toList(),
      signature: 'mock-created-signature',
    );
  }

  @override
  Future<DP1Call> getPlaylistById(String playlistId,
      {bool usingCache = true}) async {
    // Mock playlist data
    return DP1Call(
      dpVersion: '1.0.0',
      id: playlistId,
      slug: 'mock-playlist',
      title: 'Mock Playlist',
      created: DateTime.now(),
      defaults: <String, dynamic>{'display': <String, dynamic>{}},
      items: [
        DP1Item(
          duration: 30,
          provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
              chain: DP1ProvenanceChain.evm,
              standard: DP1ProvenanceStandard.erc721,
              address: '0x1234567890123456789012345678901234567890',
              tokenId: '1',
            ),
          ),
          title: 'Mock Artwork 1',
          source: 'https://example.com/mock-image-1.jpg',
        ),
        DP1Item(
          duration: 45,
          provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
              chain: DP1ProvenanceChain.evm,
              standard: DP1ProvenanceStandard.erc721,
              address: '0x1234567890123456789012345678901234567890',
              tokenId: '2',
            ),
          ),
          title: 'Mock Artwork 2',
          source: 'https://example.com/mock-image-2.jpg',
        ),
      ],
      signature: 'mock-signature',
    );
  }

  @override
  Future<List<DP1Call>> getPlaylistsByChannel(Channel channel,
      {bool usingCache = true}) async {
    // Mock playlists for a channel
    return [
      DP1Call(
        dpVersion: '1.0.0',
        id: 'mock-playlist-1',
        slug: 'mock-playlist-1',
        title: 'Mock Playlist 1',
        created: DateTime.now(),
        defaults: <String, dynamic>{'display': <String, dynamic>{}},
        items: [
          DP1Item(
            duration: 30,
            provenance: DP1Provenance(
              type: DP1ProvenanceType.onChain,
              contract: DP1Contract(
                chain: DP1ProvenanceChain.evm,
                standard: DP1ProvenanceStandard.erc721,
                address: '0x1234567890123456789012345678901234567890',
                tokenId: '1',
              ),
            ),
            title: 'Mock Artwork 1',
            source: 'https://example.com/mock-image-1.jpg',
          ),
        ],
        signature: 'mock-signature-1',
      ),
      DP1Call(
        dpVersion: '1.0.0',
        id: 'mock-playlist-2',
        slug: 'mock-playlist-2',
        title: 'Mock Playlist 2',
        created: DateTime.now(),
        defaults: <String, dynamic>{'display': <String, dynamic>{}},
        items: [
          DP1Item(
            duration: 45,
            provenance: DP1Provenance(
              type: DP1ProvenanceType.onChain,
              contract: DP1Contract(
                chain: DP1ProvenanceChain.evm,
                standard: DP1ProvenanceStandard.erc721,
                address: '0x1234567890123456789012345678901234567890',
                tokenId: '2',
              ),
            ),
            title: 'Mock Artwork 2',
            source: 'https://example.com/mock-image-2.jpg',
          ),
        ],
        signature: 'mock-signature-2',
      ),
    ];
  }

  @override
  Future<List<DP1Call>> getAllPlaylistsFromAllChannel(
      {bool usingCache = true}) async {
    // Mock all playlists from all channels
    return [
      DP1Call(
        dpVersion: '1.0.0',
        id: 'mock-all-playlist-1',
        slug: 'mock-all-playlist-1',
        title: 'Mock All Playlist 1',
        created: DateTime.now(),
        defaults: <String, dynamic>{'display': <String, dynamic>{}},
        items: [
          DP1Item(
            duration: 30,
            provenance: DP1Provenance(
              type: DP1ProvenanceType.onChain,
              contract: DP1Contract(
                chain: DP1ProvenanceChain.evm,
                standard: DP1ProvenanceStandard.erc721,
                address: '0x1234567890123456789012345678901234567890',
                tokenId: '1',
              ),
            ),
            title: 'Mock All Artwork 1',
            source: 'https://example.com/mock-all-image-1.jpg',
          ),
        ],
        signature: 'mock-all-signature-1',
      ),
    ];
  }

  @override
  Future<DP1PlaylistResponse> getAllPlaylists({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    final playlists = await getAllPlaylistsFromAllChannel();
    return DP1PlaylistResponse(playlists, false, null);
  }

  @override
  Channel? getChannelByPlaylistId(String playlistId) {
    // Mock channel for playlist
    return Channel(
      id: 'mock-channel-for-playlist',
      slug: 'mock-channel-for-playlist',
      title: 'Mock Channel for Playlist',
      summary: 'Mock channel for playlist description',
      created: DateTime.now(),
      playlists: [
        'https://example.com/mock-playlist.json',
      ],
    );
  }

  @override
  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    String? channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    // Mock playlists response
    final mockPlaylists = [
      DP1Call(
        dpVersion: '1.0.0',
        id: 'mock-playlist-response-1',
        slug: 'mock-playlist-response-1',
        title: 'Mock Playlist Response 1',
        created: DateTime.now(),
        defaults: <String, dynamic>{'display': <String, dynamic>{}},
        items: [
          DP1Item(
            duration: 30,
            provenance: DP1Provenance(
              type: DP1ProvenanceType.onChain,
              contract: DP1Contract(
                chain: DP1ProvenanceChain.evm,
                standard: DP1ProvenanceStandard.erc721,
                address: '0x1234567890123456789012345678901234567890',
                tokenId: '1',
              ),
            ),
            title: 'Mock Response Artwork 1',
            source: 'https://example.com/mock-response-image-1.jpg',
          ),
        ],
        signature: 'mock-response-signature-1',
      ),
    ];

    return DP1PlaylistResponse(mockPlaylists, false, null);
  }

  @override
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    // Mock playlist items response
    return DP1PlaylistItemsResponse([], false, null);
  }

  @override
  Future<Channel> getChannelDetail(String channelId,
      {bool usingCache = true}) async {
    // Mock channel detail
    return Channel(
      id: channelId,
      slug: 'mock-channel-detail',
      title: 'Mock Channel Detail',
      summary: 'Mock channel detail description',
      created: DateTime.now(),
      playlists: [
        'https://example.com/mock-playlist-detail.json',
      ],
    );
  }
}
