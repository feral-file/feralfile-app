import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/util/eth_utils.dart';
import 'package:sentry/sentry.dart';

/// Subject type for change journal entries
/// Based on ff-indexer-v2: token, owner, balance, metadata, enrichment_source
enum SubjectType {
  token,
  owner,
  balance,
  metadata,
  enrichmentSource,
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
      case SubjectType.enrichmentSource:
        return 'enrich_source';
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
      case 'enrich_source':
        return SubjectType.enrichmentSource;
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
    required this.tokenNumber,
    required this.tokenId,
    this.from,
    this.to,
    this.quantity,
    this.txHash,
  });

  final String chain; // e.g., "eip155:1", "tezos:mainnet"
  final String standard; // e.g., "erc721", "erc1155", "fa2"
  final String contract; // Contract address
  final String tokenNumber; // Token number
  final String? from; // Sender address (null for mints)
  final String? to; // Receiver address (null for burns)
  final String? quantity; // Quantity transferred/minted/burned
  final int tokenId;
  final String? txHash;

  factory ProvenanceChangeMeta.fromJson(Map<String, dynamic> json) =>
      ProvenanceChangeMeta(
        chain: json['chain'] as String,
        standard: json['standard'] as String,
        contract: json['contract'] as String,
        tokenNumber: json['token_number'] as String,
        tokenId: int.parse(json['token_id'].toString()),
        from: json['from'] as String?,
        to: json['to'] as String?,
        quantity: json['quantity'] as String?,
        txHash: json['tx_hash'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'chain': chain,
        'standard': standard,
        'contract': contract,
        'token_number': tokenNumber,
        'token_id': tokenId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (quantity != null) 'quantity': quantity,
        if (txHash != null) 'tx_hash': txHash,
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

  String? get tokenCid {
    return "$chain:$standard:$contract:$tokenNumber";
  }
}

/// MetadataChangeMeta represents the metadata for metadata update changes
/// It stores the old and new values of normalized metadata fields to track what changed
class MetadataChangeMeta implements ChangeMeta {
  MetadataChangeMeta({
    required this.old,
    required this.new_,
    required this.tokenId,
  });

  final MetadataFields old; // Previous metadata values
  final MetadataFields new_; // New metadata values
  final int tokenId;

  factory MetadataChangeMeta.fromJson(Map<String, dynamic> json) =>
      MetadataChangeMeta(
        old: MetadataFields.fromJson(json['old'] as Map<String, dynamic>?),
        new_: MetadataFields.fromJson(json['new'] as Map<String, dynamic>?),
        tokenId: int.parse(json['token_id'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'old': old.toJson(),
        'new': new_.toJson(),
        'token_id': tokenId,
      };
}

/// EnrichmentSourceFields represents the enrichment source fields we track for changes
class EnrichmentSourceFields {
  EnrichmentSourceFields({
    this.vendor,
    this.vendorHash,
    this.name,
    this.description,
    this.animationUrl,
    this.imageUrl,
    this.artists,
    this.mimeType,
  });

  final String? vendor; // Vendor type (artblocks, fxhash, etc.)
  final String? vendorHash; // Hash of vendor JSON
  final String? name;
  final String? description;
  final String? animationUrl;
  final String? imageUrl;
  final List<ChangeArtist>? artists;
  final String? mimeType;

  factory EnrichmentSourceFields.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return EnrichmentSourceFields();
    }
    return EnrichmentSourceFields(
      vendor: json['vendor'] as String?,
      vendorHash: json['vendor_hash'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      animationUrl: json['animation_url'] as String?,
      imageUrl: json['image_url'] as String?,
      artists: json['artists'] != null
          ? List<ChangeArtist>.from(
              (json['artists'] as List<dynamic>).map(
                (x) => ChangeArtist.fromJson(x as Map<String, dynamic>),
              ),
            )
          : null,
      mimeType: json['mime_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (vendor != null) 'vendor': vendor,
        if (vendorHash != null) 'vendor_hash': vendorHash,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (animationUrl != null) 'animation_url': animationUrl,
        if (imageUrl != null) 'image_url': imageUrl,
        if (artists != null)
          'artists': artists!.map((x) => x.toJson()).toList(),
        if (mimeType != null) 'mime_type': mimeType,
      };
}

/// EnrichmentSourceChangeMeta represents the metadata for enrichment source update changes
/// It stores the old and new values of enrichment source fields to track what changed
class EnrichmentSourceChangeMeta implements ChangeMeta {
  EnrichmentSourceChangeMeta({
    required this.old,
    required this.new_,
    required this.tokenId,
  });

  final EnrichmentSourceFields old; // Previous enrichment source values
  final EnrichmentSourceFields new_; // New enrichment source values
  final int tokenId;

  factory EnrichmentSourceChangeMeta.fromJson(Map<String, dynamic> json) =>
      EnrichmentSourceChangeMeta(
        old: EnrichmentSourceFields.fromJson(
            json['old'] as Map<String, dynamic>?),
        new_: EnrichmentSourceFields.fromJson(
            json['new'] as Map<String, dynamic>?),
        tokenId: int.parse(json['token_id'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'old': old.toJson(),
        'new': new_.toJson(),
        'token_id': tokenId,
      };
}

/// Change journal entry
class Change {
  final int id;
  final SubjectType subjectType;
  final String subjectId;
  final DateTime changedAt;
  final Map<String, dynamic>? _metaRaw;
  final DateTime createdAt;
  final DateTime updatedAt;

  Change({
    required this.id,
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
        case SubjectType.enrichmentSource:
          return EnrichmentSourceChangeMeta.fromJson(_metaRaw);
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

  int? get tokenId {
    if (metaParsed is ProvenanceChangeMeta) {
      return (metaParsed as ProvenanceChangeMeta).tokenId;
    }
    if (metaParsed is MetadataChangeMeta) {
      return (metaParsed as MetadataChangeMeta).tokenId;
    }
    if (metaParsed is EnrichmentSourceChangeMeta) {
      return (metaParsed as EnrichmentSourceChangeMeta).tokenId;
    }
    return null;
  }

  String? get tokenCid {
    if (metaParsed is ProvenanceChangeMeta) {
      return (metaParsed! as ProvenanceChangeMeta).tokenCid;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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

  bool isEnrichmentSourceUpdate() {
    return metaParsed is EnrichmentSourceChangeMeta;
  }
}

/// Paginated changes list
class ChangeList {
  ChangeList({
    required this.items,
    this.offset,
    required this.total,
    this.nextAnchor,
  });

  final List<Change> items;
  final int? offset;
  final int total;
  final int? nextAnchor;

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
        nextAnchor: int.tryParse(json['next_anchor'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((x) => x.toJson()).toList(),
        'offset': offset,
        'total': total,
        if (nextAnchor != null) 'next_anchor': nextAnchor,
      };
}

/// Request model for querying changes
class QueryChangesRequest {
  QueryChangesRequest({
    this.tokenCids = const [],
    this.addresses = const [],
    this.limit = 20,
    this.anchor,
  });

  final List<String> tokenCids;
  final List<String> addresses;
  final int? anchor;
  final int limit;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'limit': limit,
    };

    if (tokenCids.isNotEmpty) {
      json['token_cids'] = tokenCids;
    }

    if (addresses.isNotEmpty) {
      json['addresses'] = addresses;
    }

    if (anchor != null) {
      json['anchor'] = anchor;
    }

    return json;
  }
}
