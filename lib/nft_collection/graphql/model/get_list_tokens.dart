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
    this.offset = 0,
    this.chains = const [
      'eip155:1',
      'tezos:mainnet',
    ],
    this.contractAddresses = const [],
    this.tokenIds = const [],
    this.tokenCids = const [],
    this.tokenNumbers = const [],
    this.limit = indexerTokensPageSize,
  });

  final List<String> owners;
  final int offset;
  // New API fields
  final List<String> chains;
  final List<String> contractAddresses;
  final List<int> tokenIds;
  final List<String> tokenCids;
  final List<String> tokenNumbers;
  final int? limit;

  Map<String, dynamic> toJson() {
    final limitValue = limit;
    return <String, dynamic>{
      'owners': owners,
      'chains': chains,
      'contract_addresses': contractAddresses,
      'token_ids': tokenIds,
      'token_cids': tokenCids,
      'token_numbers': tokenNumbers,
      'limit': limitValue,
      'offset': offset,
    };
  }
}

class QueryGetTokenByCidRequest {
  QueryGetTokenByCidRequest({
    required this.cid,
    this.ownersLimit = 10,
    this.ownersOffset = 0,
    this.provenanceEventsLimit = 10,
    this.provenanceEventsOffset = 0,
    this.provenanceEventsOrder = Order.desc,
  });

  final String cid;
  final int ownersLimit;
  final int ownersOffset;
  final int provenanceEventsLimit;
  final int provenanceEventsOffset;
  final Order provenanceEventsOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cid': cid,
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
