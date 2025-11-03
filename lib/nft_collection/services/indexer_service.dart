import 'dart:async';

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/data/api/indexer_api.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/graphql/queries/queries.dart';
import 'package:autonomy_flutter/nft_collection/models/identity.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

abstract class NftIndexerServiceBase {
  Future<List<AssetToken>> getNftTokens(
    QueryListTokensRequest request,
  );

  Future<Identity> getIdentity(QueryIdentityRequest request);

  Future<List<AssetToken>> getAssetTokens(List<DP1Item> items);

  Stream<List<AssetToken>> getAssetTokensStream(
    List<String> addresses, {
    int pageSize = 50,
    DateTime? lastUpdatedAt,
  });
}

class NftIndexerService implements NftIndexerServiceBase {
  NftIndexerService(this._client, this._indexerApi);

  final IndexerClient _client;
  final IndexerApi _indexerApi;

  /*
  getNftTokens
  params: QueryListTokensRequest
  return: List<AssetToken>
  description: Get the list of asset tokens from the indexer
  */
  @override
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
      AssetToken.fromGraphQL,
    );
    final assetTokens = data.tokens;

    return assetTokens;
  }

  // /*
  // getNftCompactedTokens
  // params: QueryListTokensRequest
  // return: List<CompactedAssetToken>
  // description: Get the list of asset tokens from the indexer
  // */
  // @override
  // Future<List<CompactedAssetToken>> getNftCompactedTokens(
  //     QueryListTokensRequest request,
  //     {bool usingArtBlock = false}) async {
  //   final vars = request.toJson();
  //   final result = await _client.query(
  //     doc: getCompactedTokens,
  //     vars: vars,
  //   );
  //   if (result == null) {
  //     return [];
  //   }
  //   final data = QueryListTokensResponse.fromJson(
  //     Map<String, dynamic>.from(result as Map),
  //     CompactedAssetToken.fromJsonGraphQl,
  //   );
  //   final compactedAssetTokens = data.tokens;
  //
  //   if (!usingArtBlock) {
  //     return compactedAssetTokens;
  //   } else {
  //     // missing artist compactedAssetToken
  //     final missingArtistAssetTokens = compactedAssetTokens.where((token) {
  //       final artistAddress = token.asset?.artistID;
  //       return artistAddress == '0x0000000000000000000000000000000000000000';
  //     }).toList();
  //     if (missingArtistAssetTokens.isEmpty) {
  //       return compactedAssetTokens;
  //     }
  //     // Build a replacement map for tokens that need artist enrichment
  //     final Map<String, CompactedAssetToken> replacementById = {};
  //     for (final compactedAssetToken in missingArtistAssetTokens) {
  //       final asset = compactedAssetToken.asset;
  //       if (asset == null) {
  //         replacementById[compactedAssetToken.id] = compactedAssetToken;
  //         continue;
  //       }
  //       final artblockArtist = await _artBlockService.getArtistByToken(
  //           contractAddress: compactedAssetToken.contractAddress!.toLowerCase(),
  //           tokenId: compactedAssetToken.tokenId!);
  //       if (artblockArtist == null) {
  //         replacementById[compactedAssetToken.id] = compactedAssetToken;
  //         continue;
  //       }
  //       final newCompactedAsset = asset.copyWith(
  //           artistID: artblockArtist.address, artistName: artblockArtist.name);
  //       replacementById[compactedAssetToken.id] =
  //           compactedAssetToken.copyWith(asset: newCompactedAsset);
  //     }
  //     // Rebuild the list preserving original order, replacing where applicable
  //     final List<CompactedAssetToken> finalList = compactedAssetTokens
  //         .map((t) => replacementById[t.id] ?? t)
  //         .toList(growable: false);
  //     return finalList;
  //   }
  // }

  @override
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

  @override
  Future<List<AssetToken>> getAssetTokens(List<DP1Item> items) async {
    final indexIds = items.map((item) => item.cid).whereType<String>().toList();
    final assetTokens = await getNftTokens(
      QueryListTokensRequest(ids: indexIds),
    );
    return List<AssetToken>.from(assetTokens).toList();
  }

  /// Get AssetTokens with pagination and return as Stream
  /// This method fetches tokens in batches to avoid loading all at once
  ///
  /// [addresses] - List of owner addresses to fetch tokens for
  /// [pageSize] - Number of tokens to fetch per page (default: 50)
  /// [lastUpdatedAt] - Optional timestamp to filter tokens updated after this time
  ///
  /// Returns a Stream of List<AssetToken> where each emission contains a batch of tokens
  @override
  Stream<List<AssetToken>> getAssetTokensStream(
    List<String> addresses, {
    int pageSize = 50,
    DateTime? lastUpdatedAt,
  }) async* {
    if (addresses.isEmpty) return;

    var offset = 0;
    var hasMoreData = true;

    while (hasMoreData) {
      final request = QueryListTokensRequest(
        owners: addresses,
        offset: offset,
        size: pageSize,
        lastUpdatedAt: lastUpdatedAt,
      );

      final tokens = await getNftTokens(request);

      if (tokens.isEmpty) {
        hasMoreData = false;
      } else {
        yield tokens;
        offset += tokens.length;

        // If we got fewer tokens than requested, we've reached the end
        if (tokens.length < pageSize) {
          hasMoreData = false;
        }
      }
    }
  }

  Future<void> indexTokenHistory(String indexID) {
    final map = {'indexID': indexID};
    return _indexerApi.indexTokenHistory(map);
  }
}
