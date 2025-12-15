import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_collection.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_token_configurations.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/graphql/queries/collection_queries.dart';
import 'package:autonomy_flutter/nft_collection/graphql/queries/queries.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/identity.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';

class IndexerService {
  IndexerService(this._client);

  final IndexerClient _client;

  Future<List<AssetToken>> getNftTokens(QueryListTokensRequest request) async {
    final vars = request.toJson();
    final result = await _client.query(
      doc: getTokens,
      vars: vars,
    );
    if (result == null) {
      return [];
    }
    final data = QueryListTokensResponse.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
    return data.tokens;
  }

  Future<Identity> getIdentity(QueryIdentityRequest request) async {
    final vars = request.toJson();
    final result = await _client.query(
      doc: identity,
      vars: vars,
    );
    if (result == null) {
      return Identity('', '', '');
    }
    final data = QueryIdentityResponse.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
    return data.identity;
  }

  Future<List<UserCollection>> getCollectionsByAddresses(
    List<String> addresses,
  ) async {
    final vars = {'creators': addresses, 'size': 100, 'offset': 0};
    final res = await _client.query(doc: collectionQuery, vars: vars);
    final data = QueryListCollectionResponse.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
    return data.collections;
  }

  Future<List<AssetToken>> getCollectionListToken(String collectionId) async {
    final res = await _client.query(
      doc: getColectionTokenQuery,
      vars: {'collectionID': collectionId, 'offset': 0, 'size': 100},
    );
    final data =
        QueryListTokensResponse.fromJson(Map<String, dynamic>.from(res as Map));
    return data.tokens;
  }

  Future<ArtistDisplaySetting?> getTokenConfiguration(String tokenId) async {
    final response = await _client.query(
      doc: getTokenConfigurations,
      vars: {'tokenId': tokenId},
    );

    if (response == null) {
      return null;
    }

    final data = QueryListTokenConfigurationsResponse.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
    return data.tokenConfigurations.firstOrNull;
  }
}
