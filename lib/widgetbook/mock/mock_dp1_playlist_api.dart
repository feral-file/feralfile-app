import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';

class MockDP1PlaylistApi implements DP1FeedApi {
  @override
  Future<DP1Call> createPlaylist(
    Map<String, dynamic> body,
  ) async {
    // Mock creating a playlist
    return DP1Call(
      dpVersion: '1.0.0',
      id: 'mock-created-playlist-id',
      slug: 'mock-created-playlist',
      title: (body['title'] as String?) ?? 'Mock Created Playlist',
      created: DateTime.now(),
      defaults: (body['defaults'] as Map<String, dynamic>?) ??
          <String, dynamic>{'display': <String, dynamic>{}},
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
          title: 'Mock Created Artwork 1',
          source: 'https://example.com/mock-created-image-1.jpg',
        ),
      ],
      signature: 'mock-created-signature',
    );
  }

  @override
  Future<DP1Call> getPlaylistById(String playlistId) async {
    // Mock getting a playlist by ID
    return DP1Call(
      dpVersion: '1.0.0',
      id: playlistId,
      slug: 'mock-playlist-$playlistId',
      title: 'Mock Playlist $playlistId',
      created: DateTime.now().subtract(const Duration(days: 1)),
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
              tokenId: '1',
            ),
          ),
          title: 'Mock Artwork for $playlistId',
          source: 'https://example.com/mock-image-$playlistId.jpg',
        ),
        DP1Item(
          duration: 60,
          provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
              chain: DP1ProvenanceChain.evm,
              standard: DP1ProvenanceStandard.erc721,
              address: '0x1234567890123456789012345678901234567890',
              tokenId: '2',
            ),
          ),
          title: 'Mock Artwork 2 for $playlistId',
          source: 'https://example.com/mock-image-2-$playlistId.jpg',
        ),
      ],
      signature: 'mock-signature-$playlistId',
    );
  }

  @override
  Future<DP1PlaylistResponse> getAllPlaylists({
    String? channelId,
    String? cursor,
    int? limit,
  }) async {
    // Mock getting all playlists
    final mockPlaylists = [
      DP1Call(
        dpVersion: '1.0.0',
        id: 'mock-playlist-1',
        slug: 'mock-playlist-1',
        title: 'Mock Playlist 1',
        created: DateTime.now().subtract(const Duration(days: 1)),
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
        created: DateTime.now().subtract(const Duration(days: 2)),
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
      DP1Call(
        dpVersion: '1.0.0',
        id: 'mock-playlist-3',
        slug: 'mock-playlist-3',
        title: 'Mock Playlist 3',
        created: DateTime.now().subtract(const Duration(days: 3)),
        defaults: <String, dynamic>{'display': <String, dynamic>{}},
        items: [
          DP1Item(
            duration: 60,
            provenance: DP1Provenance(
              type: DP1ProvenanceType.onChain,
              contract: DP1Contract(
                chain: DP1ProvenanceChain.evm,
                standard: DP1ProvenanceStandard.erc721,
                address: '0x1234567890123456789012345678901234567890',
                tokenId: '3',
              ),
            ),
            title: 'Mock Artwork 3',
            source: 'https://example.com/mock-image-3.jpg',
          ),
        ],
        signature: 'mock-signature-3',
      ),
    ];

    return DP1PlaylistResponse(
      mockPlaylists,
      false, // hasMore
      null, // cursor
    );
  }

  @override
  Future<Channel> createChannel(
    Map<String, dynamic> body,
  ) async {
    // Mock creating a playlist group
    return Channel(
      id: 'mock-created-group-id',
      slug: 'mock-created-group',
      title: (body['title'] as String?) ?? 'Mock Created Group',
      summary: (body['summary'] as String?) ?? 'Mock created group description',
      created: DateTime.now(),
      playlists: [
        'https://example.com/mock-created-playlist.json',
      ],
    );
  }

  @override
  Future<Channel> getChannelById(String channelId) async {
    // Mock getting a playlist group by ID
    return Channel(
      id: channelId,
      slug: 'mock-channel-$channelId',
      title: 'Mock Channel $channelId',
      summary: 'Mock channel description for $channelId',
      created: DateTime.now().subtract(const Duration(days: 1)),
      playlists: [
        'https://example.com/mock-playlist-1.json',
        'https://example.com/mock-playlist-2.json',
        'https://example.com/mock-playlist-3.json',
      ],
    );
  }

  @override
  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
  }) async {
    // Mock getting all playlist groups
    final mockChannels = [
      Channel(
        id: 'mock-channel-1',
        slug: 'mock-channel-1',
        title: 'Mock Channel 1',
        summary: 'Mock channel description 1',
        created: DateTime.now().subtract(const Duration(days: 1)),
        playlists: [
          'https://example.com/mock-playlist-1.json',
          'https://example.com/mock-playlist-2.json',
        ],
      ),
      Channel(
        id: 'mock-channel-2',
        slug: 'mock-channel-2',
        title: 'Mock Channel 2',
        summary: 'Mock channel description 2',
        created: DateTime.now().subtract(const Duration(days: 2)),
        playlists: [
          'https://example.com/mock-playlist-3.json',
        ],
      ),
      Channel(
        id: 'mock-channel-3',
        slug: 'mock-channel-3',
        title: 'Mock Channel 3',
        summary: 'Mock channel description 3',
        created: DateTime.now().subtract(const Duration(days: 3)),
        playlists: [
          'https://example.com/mock-playlist-4.json',
          'https://example.com/mock-playlist-5.json',
          'https://example.com/mock-playlist-6.json',
        ],
      ),
    ];

    return DP1ChannelsResponse(
      mockChannels,
      false, // hasMore
      null, // cursor
    );
  }

  @override
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? channelId,
    String? cursor,
    int? limit,
  }) async {
    // Mock getting playlist items
    return DP1PlaylistItemsResponse(
      [], // items - empty for now
      false, // hasMore
      null, // cursor
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
