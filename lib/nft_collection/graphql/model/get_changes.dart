import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/util/eth_utils.dart';
import 'package:sentry/sentry.dart';

/// Subject type for change journal entries
/// Based on ff-indexer-v2: token, owner, balance, metadata
enum SubjectType {
  token,
  owner,
  balance,
  metadata,
}

extension SubjectTypeJson on SubjectType {
  String toJson() {
    switch (this) {
      case SubjectType.token:
        return 'token';
      case SubjectType.owner:
        return 'owner';
      case SubjectType.balance:
        return 'balance';
      case SubjectType.metadata:
        return 'metadata';
    }
  }

  static SubjectType? fromJson(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'token':
        return SubjectType.token;
      case 'owner':
        return SubjectType.owner;
      case 'balance':
        return SubjectType.balance;
      case 'metadata':
        return SubjectType.metadata;
      default:
        return null;
    }
  }
}

/// Artist represents an artist/creator with their decentralized identifier and name
class ChangeArtist {
  ChangeArtist({
    required this.did,
    required this.name,
  });

  final String did;
  final String name;

  factory ChangeArtist.fromJson(Map<String, dynamic> json) => ChangeArtist(
        did: json['did'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {
        'did': did,
        'name': name,
      };
}

/// Publisher represents the publisher of the token
class ChangePublisher {
  ChangePublisher({
    this.name,
    this.url,
  });

  final String? name;
  final String? url;

  factory ChangePublisher.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ChangePublisher();
    return ChangePublisher(
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (url != null) 'url': url,
      };
}

/// MetadataFields represents the normalized metadata fields we track for changes
class MetadataFields {
  MetadataFields({
    this.animationUrl,
    this.imageUrl,
    this.artists,
    this.publisher,
    this.mimeType,
  });

  final String? animationUrl;
  final String? imageUrl;
  final List<ChangeArtist>? artists;
  final ChangePublisher? publisher;
  final String? mimeType;

  factory MetadataFields.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MetadataFields();
    return MetadataFields(
      animationUrl: json['animation_url'] as String?,
      imageUrl: json['image_url'] as String?,
      artists: json['artists'] != null
          ? List<ChangeArtist>.from(
              (json['artists'] as List<dynamic>).map(
                (x) => ChangeArtist.fromJson(x as Map<String, dynamic>),
              ),
            )
          : null,
      publisher: ChangePublisher.fromJson(
        json['publisher'] as Map<String, dynamic>?,
      ),
      mimeType: json['mime_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (animationUrl != null) 'animation_url': animationUrl,
        if (imageUrl != null) 'image_url': imageUrl,
        if (artists != null)
          'artists': artists!.map((x) => x.toJson()).toList(),
        if (publisher != null) 'publisher': publisher!.toJson(),
        if (mimeType != null) 'mime_type': mimeType,
      };
}

/// Abstract base class for change metadata
abstract class ChangeMeta {
  Map<String, dynamic> toJson();
}

/// ProvenanceChangeMeta represents the metadata for token, owner, and balance changes
/// It stores essential provenance information to quickly identify what changed without joining tables
class ProvenanceChangeMeta implements ChangeMeta {
  ProvenanceChangeMeta({
    required this.chain,
    required this.standard,
    required this.contract,
    required this.token,
    this.from,
    this.to,
    this.quantity,
  });

  final String chain; // e.g., "eip155:1", "tezos:mainnet"
  final String standard; // e.g., "erc721", "erc1155", "fa2"
  final String contract; // Contract address
  final String token; // Token number
  final String? from; // Sender address (null for mints)
  final String? to; // Receiver address (null for burns)
  final String? quantity; // Quantity transferred/minted/burned

  factory ProvenanceChangeMeta.fromJson(Map<String, dynamic> json) =>
      ProvenanceChangeMeta(
        chain: json['chain'] as String,
        standard: json['standard'] as String,
        contract: json['contract'] as String,
        token: json['token'] as String,
        from: json['from'] as String?,
        to: json['to'] as String?,
        quantity: json['quantity'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'chain': chain,
        'standard': standard,
        'contract': contract,
        'token': token,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (quantity != null) 'quantity': quantity,
      };

  bool isMint() {
    // mint is a transfer from null (or empty or null address) to a non-null address
    return (from == null || from!.isEmpty || from!.isNullAddress) &&
        (to != null && to!.isNotEmpty && !to!.isNullAddress);
  }

  bool isBurn() {
    return (to == null || to!.isEmpty || to!.isNullAddress) &&
        (from != null && from!.isNotEmpty && !from!.isNullAddress);
  }

  bool isTransfer() {
    return (from != null && from!.isNotEmpty && !from!.isNullAddress) &&
        (to != null && to!.isNotEmpty && !to!.isNullAddress);
  }
}

/// MetadataChangeMeta represents the metadata for metadata update changes
/// It stores the old and new values of normalized metadata fields to track what changed
class MetadataChangeMeta implements ChangeMeta {
  MetadataChangeMeta({
    required this.old,
    required this.new_,
  });

  final MetadataFields old; // Previous metadata values
  final MetadataFields new_; // New metadata values

  factory MetadataChangeMeta.fromJson(Map<String, dynamic> json) =>
      MetadataChangeMeta(
        old: MetadataFields.fromJson(json['old'] as Map<String, dynamic>?),
        new_: MetadataFields.fromJson(json['new'] as Map<String, dynamic>?),
      );

  Map<String, dynamic> toJson() => {
        'old': old.toJson(),
        'new': new_.toJson(),
      };
}

/// Change journal entry
class Change {
  final int id;
  final String tokenCid;
  final SubjectType subjectType;
  final String subjectId;
  final DateTime changedAt;
  final Map<String, dynamic>? _metaRaw;
  final DateTime createdAt;
  final DateTime updatedAt;

  Change({
    required this.id,
    required this.tokenCid,
    required this.subjectType,
    required this.subjectId,
    required this.changedAt,
    Map<String, dynamic>? meta,
    required this.createdAt,
    required this.updatedAt,
  }) : _metaRaw = meta;

  /// Get meta as ChangeMeta (parsed based on subjectType)
  ChangeMeta? get metaParsed {
    if (_metaRaw == null) return null;
    try {
      switch (subjectType) {
        case SubjectType.token:
        case SubjectType.owner:
        case SubjectType.balance:
          return ProvenanceChangeMeta.fromJson(_metaRaw);
        case SubjectType.metadata:
          return MetadataChangeMeta.fromJson(_metaRaw);
      }
    } catch (e, _) {
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Failed to parse change meta: $e'),
        level: SentryLevel.info,
        throwable: e,
      ));
      NftCollection.logger.info('Failed to parse change meta: $e');
      return null;
    }
  }

  /// Get raw meta map
  Map<String, dynamic>? get meta => _metaRaw;

  factory Change.fromJson(Map<String, dynamic> json) => Change(
        id: int.tryParse(json['id'].toString()) ?? 0,
        tokenCid: json['token_cid'] as String,
        subjectType:
            SubjectTypeJson.fromJson(json['subject_type'] as String?) ??
                SubjectType.token,
        subjectId: json['subject_id'] as String,
        changedAt:
            DateTime.tryParse(json['changed_at'] as String) ?? DateTime.now(),
        meta: json['meta'] != null
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : null,
        createdAt:
            DateTime.tryParse(json['created_at'] as String) ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'token_cid': tokenCid,
        'subject_type': subjectType.toJson(),
        'subject_id': subjectId,
        'changed_at': changedAt.toIso8601String(),
        'meta': _metaRaw,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool isMint() {
    return metaParsed is ProvenanceChangeMeta &&
        (metaParsed as ProvenanceChangeMeta).isMint();
  }

  bool isBurn() {
    return metaParsed is ProvenanceChangeMeta &&
        (metaParsed as ProvenanceChangeMeta).isBurn();
  }

  bool isTransfer() {
    return metaParsed is ProvenanceChangeMeta &&
        (metaParsed as ProvenanceChangeMeta).isTransfer();
  }

  bool isMetadataUpdate() {
    return metaParsed is MetadataChangeMeta;
  }
}

/// Paginated changes list
class ChangeList {
  ChangeList({
    required this.items,
    this.offset,
    required this.total,
  });

  final List<Change> items;
  final int? offset;
  final int total;

  factory ChangeList.fromJson(Map<String, dynamic> json) => ChangeList(
        items: json['items'] != null
            ? List<Change>.from(
                (json['items'] as List<dynamic>).map(
                  (x) => Change.fromJson(x as Map<String, dynamic>),
                ),
              )
            : [],
        offset: json['offset'] != null
            ? int.tryParse(json['offset'].toString())
            : null,
        total: int.tryParse(json['total'].toString()) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((x) => x.toJson()).toList(),
        'offset': offset,
        'total': total,
      };
}

/// Request model for querying changes
class QueryChangesRequest {
  QueryChangesRequest({
    this.tokenCids = const [],
    this.addresses = const [],
    this.since,
    this.limit = 20,
    this.offset = 0,
    this.order = Order.asc,
    this.expand = const [],
  });

  final List<String> tokenCids;
  final List<String> addresses;
  final String? since;
  final int limit;
  final int offset;
  final Order order;
  final List<String> expand;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'order': order.toJson(),
    };

    if (tokenCids.isNotEmpty) {
      json['token_cid'] = tokenCids;
    }

    if (addresses.isNotEmpty) {
      json['address'] = addresses;
    }

    if (since != null && since!.isNotEmpty) {
      json['since'] = since;
    }

    if (expand.isNotEmpty) {
      json['expand'] = expand;
    }

    return json;
  }
}
