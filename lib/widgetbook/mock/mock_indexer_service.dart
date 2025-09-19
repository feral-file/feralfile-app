import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/models/asset.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/identity.dart';
import 'package:autonomy_flutter/nft_collection/models/origin_token_info.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_asset_token.dart';

class MockIndexerService extends NftIndexerService {
  MockIndexerService(
      super.indexerClient, super.indexerApi, super.artBlockService);

  @override
  Future<List<AssetToken>> getNftTokens(QueryListTokensRequest request,
      {bool usingArtBlock = false}) async {
    return [
      ...MockAssetToken.all,
    ];
  }

  @override
  Future<Identity> getIdentity(QueryIdentityRequest request) async {
    return Identity('mock_account', 'ethereum', 'Mock Name');
  }

  @override
  Future<List<UserCollection>> getUserCollections(String address) async {
    return [
      UserCollection(
        id: 'mock_collection',
        externalID: 'mock_external_id',
        creators: [address],
        name: 'Mock Collection',
        description: 'Mô tả mock',
        items: 1,
        imageURL: 'https://example.com/image.jpg',
        published: true,
        source: 'mock_source',
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];
  }

  @override
  Future<List<UserCollection>> getCollectionsByAddresses(
      List<String> addresses) async {
    return addresses
        .map((addr) => UserCollection(
              id: 'mock_collection_$addr',
              externalID: 'mock_external_id_$addr',
              creators: [addr],
              name: 'Mock Collection $addr',
              description: 'Mô tả mock $addr',
              items: 1,
              imageURL: 'https://example.com/image.jpg',
              published: true,
              source: 'mock_source',
              createdAt: DateTime.now().toIso8601String(),
            ))
        .toList();
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
        provenance: <Provenance>[],
        originTokenInfo: <OriginTokenInfo>[],
        projectMetadata: null,
        swapped: false,
        attributes: null,
        burned: false,
        ipfsPinned: false,
        asset: Asset.init(indexID: 'mock_id_$collectionId'),
        isDebugged: false,
        pending: false,
      ),
    ];
  }

  @override
  Future<ArtistDisplaySetting?> getTokenConfiguration(String tokenId) async {
    return null;
  }
}
