import 'package:autonomy_flutter/nft_collection/data/api/indexer_api.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/nft_collection/models/asset.dart';

class MockIndexerApi implements IndexerApi {
  @override
  Future<List<AssetToken>> getNFTTokens(int offset) async {
    return [
      AssetToken(
        id: 'mock_token_id',
        edition: 1,
        editionName: '1',
        blockchain: 'ethereum',
        fungible: false,
        contractType: 'erc721',
        tokenId: 'mock_token',
        contractAddress: '0x123',
        balance: 1,
        owner: '0xowner',
        owners: {'0xowner': 1},
        lastActivityTime: DateTime.now(),
        lastRefreshedTime: DateTime.now(),
        provenance: [],
        originTokenInfo: [],
        projectMetadata: null,
        swapped: false,
        attributes: null,
        burned: false,
        ipfsPinned: false,
        asset: Asset.init(indexID: 'mock_token_id'),
        isDebugged: false,
        pending: false,
      )
    ];
  }

  @override
  Future<void> requestIndex(Map<String, dynamic> payload) async {}

  @override
  Future<void> indexTokenHistory(Map<String, dynamic> payload) async {}

  @override
  Future<dynamic> numberNft(String owner) async {
    return 1;
  }

  @override
  Future<List<UserCollection>> getCollection(String creator, int size) async {
    return [
      UserCollection(
        id: 'mock_collection_id',
        externalID: 'mock_external_id',
        creators: [creator],
        name: 'Mock Collection',
        description: 'Mock Description',
        items: 1,
        imageURL: 'https://example.com/image.jpg',
        published: true,
        source: 'mock_source',
        createdAt: DateTime.now().toIso8601String(),
      )
    ];
  }

  @override
  Future<List<AssetToken>> getCollectionListToken(String collectionId) async {
    return [
      AssetToken(
        id: 'mock_id_$collectionId',
        edition: 1,
        editionName: '1',
        blockchain: 'ethereum',
        fungible: false,
        contractType: 'erc721',
        tokenId: 'mock_token',
        contractAddress: '0x123',
        balance: 1,
        owner: '0xowner',
        owners: {'0xowner': 1},
        lastActivityTime: DateTime.now(),
        lastRefreshedTime: DateTime.now(),
        provenance: [],
        originTokenInfo: [],
        projectMetadata: null,
        swapped: false,
        attributes: null,
        burned: false,
        ipfsPinned: false,
        asset: Asset.init(indexID: 'mock_id_$collectionId'),
        isDebugged: false,
        pending: false,
      )
    ];
  }
}
