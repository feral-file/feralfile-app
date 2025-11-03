import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/utils/constants.dart';

class QueryListTokensResponse<T extends AssetToken> {
  QueryListTokensResponse({
    required this.tokens,
  });

  factory QueryListTokensResponse.fromJson(Map<String, dynamic> map,
      T Function(Map<String, dynamic>) fromJsonGraphQl) {
    return QueryListTokensResponse<T>(
      tokens: map['tokens']?['items'] != null
          ? List<T>.from(
              (map['tokens']?['items'] as List<dynamic>).map<T>(
                (x) => fromJsonGraphQl(x as Map<String, dynamic>),
              ),
            )
          : [],
    );
  }

  List<T> tokens;
}

class QueryListTokensRequest {
  QueryListTokensRequest({
    this.owners = const [], // backward-compat; maps to `owner`
    this.ids =
        const [], // backward-compat; maps to `token_id` when tokenIds empty
    this.offset = 0,
    this.size =
        indexerTokensPageSize, // backward-compat; maps to `limit` when limit not set
    this.sortBy = IndexerAssetTokenSortBy.lastActivityTime, // unused in new API
    // New API fields
    this.chains = const [],
    this.contractAddresses = const [],
    this.tokenIds = const [],
    this.limit,
    this.expand = const [],
    this.ownersLimit = 10,
    this.ownersOffset = 0,
    this.provenanceEventsLimit = 10,
    this.provenanceEventsOffset = 0,
    this.provenanceEventsOrder = Order.desc,
  }) : burnedIncluded = ids.any((id) => id.startsWith('bmk'));

  final List<String> owners;
  final List<String> ids;
  final int offset;
  final int size;
  final bool burnedIncluded;
  final IndexerAssetTokenSortBy sortBy;

  // New API fields
  final List<String> chains;
  final List<String> contractAddresses;
  final List<String> tokenIds;
  final int? limit;
  final List<String> expand;
  final int ownersLimit;
  final int ownersOffset;
  final int provenanceEventsLimit;
  final int provenanceEventsOffset;
  final Order provenanceEventsOrder;

  Map<String, dynamic> toJson() {
    // Provide both new and legacy keys to maintain compatibility with current queries
    final tokenIdValue = tokenIds.isNotEmpty ? tokenIds : ids;
    final limitValue = limit ?? size;
    return <String, dynamic>{
      // Legacy keys
      'owners': owners,
      'ids': ids,
      'size': size,
      // New API keys
      'owner': owners,
      'chain': chains,
      'contract_address': contractAddresses,
      'token_id': tokenIdValue,
      'limit': limitValue,
      'offset': offset,
      'expand': expand,
      'owners_limit': ownersLimit,
      'owners_offset': ownersOffset,
      'provenance_events_limit': provenanceEventsLimit,
      'provenance_events_offset': provenanceEventsOffset,
      'provenance_events_order': provenanceEventsOrder.toJson(),
      // Fields below are not used by the new API but kept for compatibility flags
      'burnedIncluded': burnedIncluded,
      'sortBy': sortBy.toJson(),
    };
  }
}

enum Order { asc, desc }

extension OrderJson on Order {
  String toJson() => this == Order.asc ? 'asc' : 'desc';
}
