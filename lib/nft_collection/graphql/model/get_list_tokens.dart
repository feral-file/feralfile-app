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

enum ExpandField {
  provenanceEvents,
  owners,
  metadataMediaAsset,
  enrichmentSourceMediaAsset,
  enrichmentSource,
}

extension ExpandFieldJson on ExpandField {
  String toJson() {
    switch (this) {
      case ExpandField.provenanceEvents:
        return 'provenance_events';
      case ExpandField.owners:
        return 'owners';
      case ExpandField.metadataMediaAsset:
        return 'metadata_media_asset';
      case ExpandField.enrichmentSourceMediaAsset:
        return 'enrichment_source_media_asset';
      case ExpandField.enrichmentSource:
        return 'enrichment_source';
    }
  }
}

class QueryListTokensRequest {
  QueryListTokensRequest({
    this.owners = const [], // backward-compat; maps to `owner`
    this.offset = 0,
    this.chains = const [
      'eip155:1',
      'tezos:mainnet',
    ],
    this.contractAddresses = const [],
    this.tokenIds = const [],
    this.tokenCids = const [],
    this.limit = indexerTokensPageSize,
    this.expand = const [
      ExpandField.provenanceEvents,
      ExpandField.owners,
      ExpandField.metadataMediaAsset,
      ExpandField.enrichmentSourceMediaAsset,
      ExpandField.enrichmentSource,
    ],
    this.ownersLimit = 255,
    this.ownersOffset = 0,
    this.provenanceEventsLimit = 50,
    this.provenanceEventsOffset = 0,
    this.provenanceEventsOrder = Order.desc,
  });

  final List<String> owners;
  final int offset;
  // New API fields
  final List<String> chains;
  final List<String> contractAddresses;
  final List<String> tokenIds;
  final List<String> tokenCids;
  final int? limit;
  final List<ExpandField> expand;
  final int ownersLimit;
  final int ownersOffset;
  final int provenanceEventsLimit;
  final int provenanceEventsOffset;
  final Order provenanceEventsOrder;

  Map<String, dynamic> toJson() {
    // Provide both new and legacy keys to maintain compatibility with current queries
    final limitValue = limit;
    return <String, dynamic>{
      // New API keys
      'owner': owners,
      'chain': chains,
      'contract_address': contractAddresses,
      'token_id': tokenIds,
      'token_cids': tokenCids,
      'limit': limitValue,
      'offset': offset,
      'expand': expand.map((e) => e.toJson()).toList(),
      'owners_limit': ownersLimit,
      'owners_offset': ownersOffset,
      'provenance_events_limit': provenanceEventsLimit,
      'provenance_events_offset': provenanceEventsOffset,
      'provenance_events_order': provenanceEventsOrder.toJson(),
      // Fields below are not used by the new API but kept for compatibility flags
    };
  }
}

class QueryGetTokenByCidRequest {
  QueryGetTokenByCidRequest({
    required this.cid,
    this.expand = const [
      ExpandField.provenanceEvents,
      ExpandField.owners,
      ExpandField.metadataMediaAsset,
      ExpandField.enrichmentSourceMediaAsset,
      ExpandField.enrichmentSource,
    ],
    this.ownersLimit = 10,
    this.ownersOffset = 0,
    this.provenanceEventsLimit = 10,
    this.provenanceEventsOffset = 0,
    this.provenanceEventsOrder = Order.desc,
  });

  final String cid;
  final List<ExpandField> expand;
  final int ownersLimit;
  final int ownersOffset;
  final int provenanceEventsLimit;
  final int provenanceEventsOffset;
  final Order provenanceEventsOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cid': cid,
        'expand': expand.map((e) => e.toJson()).toList(),
        'owners_limit': ownersLimit,
        'owners_offset': ownersOffset,
        'provenance_events_limit': provenanceEventsLimit,
        'provenance_events_offset': provenanceEventsOffset,
        'provenance_events_order': provenanceEventsOrder.toJson(),
      };
}

enum Order { asc, desc }

extension OrderJson on Order {
  String toJson() => this == Order.asc ? 'asc' : 'desc';
}
