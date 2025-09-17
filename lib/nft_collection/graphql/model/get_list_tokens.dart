import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/utils/constants.dart';

class QueryListTokensResponse<T extends CompactedAssetToken> {
  QueryListTokensResponse({
    required this.tokens,
  });

  factory QueryListTokensResponse.fromJson(Map<String, dynamic> map,
      T Function(Map<String, dynamic>) fromJsonGraphQl) {
    return QueryListTokensResponse<T>(
      tokens: map['tokens'] != null
          ? List<T>.from(
              (map['tokens'] as List<dynamic>).map<T>(
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
    this.owners = const [],
    this.ids = const [],
    this.lastUpdatedAt,
    this.offset = 0,
    this.size = indexerTokensPageSize,
  }) : burnedIncluded = ids.any((id) => id.startsWith('bmk'));

  final List<String> owners;
  final List<String> ids;
  final DateTime? lastUpdatedAt;
  final int offset;
  final int size;
  final bool burnedIncluded;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'owners': owners,
      'ids': ids,
      'lastUpdatedAt': lastUpdatedAt?.toUtc().toIso8601String(),
      'offset': offset,
      'size': size,
      'burnedIncluded': burnedIncluded,
    };
  }
}
