//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

class TokenMetadata {
  TokenMetadata({
    required this.tokenId,
    this.originJson,
    this.latestJson,
    this.latestHash,
    required this.enrichmentLevel,
    this.lastRefreshedAt,
    this.imageUrl,
    this.animationUrl,
    this.name,
    this.description,
    this.artists,
    this.publisher,
  });

  final String tokenId; // Uint64 in server, kept as string in app
  final Map<String, dynamic>? originJson;
  final Map<String, dynamic>? latestJson;
  final String? latestHash;
  final String enrichmentLevel;
  final DateTime? lastRefreshedAt;
  final String? imageUrl;
  final String? animationUrl;
  final String? name;
  final String? description;
  final List<Artist>? artists;
  final Publisher? publisher;

  factory TokenMetadata.fromMap(Map<String, dynamic> json) => TokenMetadata(
        tokenId: '${json['token_id']}',
        originJson: json['origin_json'] as Map<String, dynamic>?,
        latestJson: json['latest_json'] as Map<String, dynamic>?,
        latestHash: json['latest_hash'] as String?,
        enrichmentLevel: json['enrichment_level'] as String? ?? '',
        lastRefreshedAt: json['last_refreshed_at'] != null
            ? DateTime.tryParse(json['last_refreshed_at'] as String)
            : null,
        imageUrl: json['image_url'] as String?,
        animationUrl: json['animation_url'] as String?,
        name: json['name'] as String?,
        description: json['description'] as String?,
        artists: (json['artists'] as List?)
            ?.map((e) => Artist.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        publisher: json['publisher'] != null
            ? Publisher.fromMap(
                Map<String, dynamic>.from(json['publisher'] as Map),
              )
            : null,
      );
}

class AssetToken {
  AssetToken({
    required this.cid,
    required this.chain,
    required this.standard,
    required this.contractAddress,
    required this.tokenNumber,
    this.currentOwner,
    required this.burned,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.owners,
    this.provenanceEvents,
    this.enrichmentSource,
    this.metadataMediaAssets,
    this.enrichmentSourceMediaAssets,
  });

  final String cid; // primary key in app
  final String chain;
  final String standard;
  final String contractAddress;
  final String tokenNumber;
  final String? currentOwner;
  final bool burned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TokenMetadata? metadata;
  final PaginatedOwners? owners;
  final PaginatedProvenanceEvents? provenanceEvents;
  final EnrichmentSource? enrichmentSource;
  final List<MediaAsset>? metadataMediaAssets;
  final List<MediaAsset>? enrichmentSourceMediaAssets;

  factory AssetToken.fromGraphQL(Map<String, dynamic> json) => AssetToken(
        cid: json['token_cid'] as String? ?? json['cid'] as String,
        chain: json['chain'] as String,
        standard: json['standard'] as String,
        contractAddress: json['contract_address'] as String,
        tokenNumber: json['token_number'] as String,
        currentOwner: json['current_owner'] as String?,
        burned: json['burned'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        metadata: json['metadata'] != null
            ? TokenMetadata.fromMap(
                Map<String, dynamic>.from(json['metadata'] as Map),
              )
            : null,
        owners: json['owners'] != null
            ? PaginatedOwners.fromMap(
                Map<String, dynamic>.from(json['owners'] as Map),
              )
            : null,
        provenanceEvents: json['provenance_events'] != null
            ? PaginatedProvenanceEvents.fromMap(
                Map<String, dynamic>.from(json['provenance_events'] as Map),
              )
            : null,
        enrichmentSource: json['enrichment_source'] != null
            ? EnrichmentSource.fromMap(
                Map<String, dynamic>.from(json['enrichment_source'] as Map),
              )
            : null,
        metadataMediaAssets: (json['metadata_media_assets'] as List?)
            ?.map(
                (e) => MediaAsset.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        enrichmentSourceMediaAssets: (json['enrichment_source_media_assets']
                as List?)
            ?.map(
                (e) => MediaAsset.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  factory AssetToken.fromRest(Map<String, dynamic> json) => AssetToken(
        cid: json['token_cid'] as String? ?? json['cid'] as String,
        chain: json['chain'] as String,
        standard: json['standard'] as String,
        contractAddress: json['contract_address'] as String,
        tokenNumber: json['token_number'] as String,
        currentOwner: json['current_owner'] as String?,
        burned: json['burned'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        metadata: json['metadata'] != null
            ? TokenMetadata.fromMap(
                Map<String, dynamic>.from(json['metadata'] as Map),
              )
            : null,
        owners: json['owners'] != null
            ? PaginatedOwners.fromMap(
                Map<String, dynamic>.from(json['owners'] as Map),
              )
            : null,
        provenanceEvents: json['provenance_events'] != null
            ? PaginatedProvenanceEvents.fromMap(
                Map<String, dynamic>.from(json['provenance_events'] as Map),
              )
            : null,
        enrichmentSource: json['enrichment_source'] != null
            ? EnrichmentSource.fromMap(
                Map<String, dynamic>.from(json['enrichment_source'] as Map),
              )
            : null,
        metadataMediaAssets: (json['metadata_media_assets'] as List?)
            ?.map(
                (e) => MediaAsset.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        enrichmentSourceMediaAssets: (json['enrichment_source_media_assets']
                as List?)
            ?.map(
                (e) => MediaAsset.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Artist {
  Artist({required this.did, required this.name});

  final String did;
  final String name;

  factory Artist.fromMap(Map<String, dynamic> json) => Artist(
        did: json['did'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'did': did,
        'name': name,
      };
}

class Publisher {
  Publisher({this.name, this.url});

  final String? name;
  final String? url;

  factory Publisher.fromMap(Map<String, dynamic> json) => Publisher(
        name: json['name'] as String?,
        url: json['url'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (name != null) 'name': name,
        if (url != null) 'url': url,
      };
}

class Owner {
  Owner({
    required this.ownerAddress,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  final String ownerAddress;
  final String quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Owner.fromMap(Map<String, dynamic> json) => Owner(
        ownerAddress: json['owner_address'] as String,
        quantity: json['quantity'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class PaginatedOwners {
  PaginatedOwners({required this.items, this.offset, required this.total});

  final List<Owner> items;
  final String? offset; // Uint64 as string
  final String total; // Uint64 as string

  factory PaginatedOwners.fromMap(Map<String, dynamic> json) => PaginatedOwners(
        items: (json['items'] as List)
            .map((e) => Owner.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        offset: json['offset']?.toString(),
        total: json['total'].toString(),
      );
}

class ProvenanceEvent {
  ProvenanceEvent({
    required this.id,
    required this.tokenId,
    required this.chain,
    required this.eventType,
    this.fromAddress,
    this.toAddress,
    this.quantity,
    this.txHash,
    this.blockNumber,
    this.blockHash,
    required this.timestamp,
    this.raw,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id; // Uint64 as string
  final String tokenId; // Uint64 as string
  final String chain;
  final String eventType;
  final String? fromAddress;
  final String? toAddress;
  final String? quantity;
  final String? txHash;
  final String? blockNumber; // Uint64 as string
  final String? blockHash;
  final DateTime timestamp;
  final Map<String, dynamic>? raw;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProvenanceEvent.fromMap(Map<String, dynamic> json) => ProvenanceEvent(
        id: json['id'].toString(),
        tokenId: json['token_id'].toString(),
        chain: json['chain'] as String,
        eventType: json['event_type'] as String,
        fromAddress: json['from_address'] as String?,
        toAddress: json['to_address'] as String?,
        quantity: json['quantity'] as String?,
        txHash: json['tx_hash'] as String?,
        blockNumber: json['block_number']?.toString(),
        blockHash: json['block_hash'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        raw: json['raw'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class PaginatedProvenanceEvents {
  PaginatedProvenanceEvents({
    required this.items,
    this.offset,
    required this.total,
  });

  final List<ProvenanceEvent> items;
  final String? offset; // Uint64 as string
  final String total; // Uint64 as string

  factory PaginatedProvenanceEvents.fromMap(Map<String, dynamic> json) =>
      PaginatedProvenanceEvents(
        items: (json['items'] as List)
            .map((e) =>
                ProvenanceEvent.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        offset: json['offset']?.toString(),
        total: json['total'].toString(),
      );
}

class EnrichmentSource {
  EnrichmentSource({
    required this.tokenId,
    required this.vendor,
    this.vendorJson,
    this.vendorHash,
    this.imageUrl,
    this.animationUrl,
    this.name,
    this.description,
    this.artists,
    this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  final String tokenId; // Uint64 as string
  final String vendor;
  final Map<String, dynamic>? vendorJson;
  final String? vendorHash;
  final String? imageUrl;
  final String? animationUrl;
  final String? name;
  final String? description;
  final List<Artist>? artists;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EnrichmentSource.fromMap(Map<String, dynamic> json) =>
      EnrichmentSource(
        tokenId: json['token_id'].toString(),
        vendor: json['vendor'] as String,
        vendorJson: json['vendor_json'] as Map<String, dynamic>?,
        vendorHash: json['vendor_hash'] as String?,
        imageUrl: json['image_url'] as String?,
        animationUrl: json['animation_url'] as String?,
        name: json['name'] as String?,
        description: json['description'] as String?,
        artists: (json['artists'] as List?)
            ?.map((e) => Artist.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        mimeType: json['mime_type'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class MediaAsset {
  MediaAsset({
    required this.id,
    required this.sourceUrl,
    this.mimeType,
    this.fileSizeBytes,
    required this.provider,
    this.providerAssetId,
    this.providerMetadata,
    required this.variantUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String sourceUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final String provider;
  final String? providerAssetId;
  final Map<String, dynamic>? providerMetadata;
  final Map<String, dynamic> variantUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MediaAsset.fromMap(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as int,
        sourceUrl: json['source_url'] as String,
        mimeType: json['mime_type'] as String?,
        fileSizeBytes: (json['file_size_bytes'] is int)
            ? json['file_size_bytes'] as int
            : (json['file_size_bytes'] as num?)?.toInt(),
        provider: json['provider'] as String,
        providerAssetId: json['provider_asset_id'] as String?,
        providerMetadata: json['provider_metadata'] as Map<String, dynamic>?,
        variantUrls: Map<String, dynamic>.from(json['variant_urls'] as Map),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
