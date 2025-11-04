//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

class TokenMetadata {
  TokenMetadata({
    this.name,
    this.description,
    this.imageUrl,
    this.animationUrl,
    this.mimeType,
    this.artists,
    this.publisher,
  });

  final String? name;
  final String? description;
  final String? imageUrl;
  final String? animationUrl;
  final String? mimeType;
  final List<Artist>? artists;
  final Publisher? publisher;

  factory TokenMetadata.fromJson(Map<String, dynamic> json) => TokenMetadata(
        name: json['name'] as String?,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        animationUrl: json['animation_url'] as String?,
        mimeType: json['mime_type'] as String?,
        artists: (json['artists'] as List?)
            ?.map((e) => Artist.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        publisher: json['publisher'] != null
            ? Publisher.fromJson(
                Map<String, dynamic>.from(json['publisher'] as Map),
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        if (animationUrl != null) 'animation_url': animationUrl,
        if (mimeType != null) 'mime_type': mimeType,
        if (artists != null)
          'artists': artists!.map((a) => a.toJson()).toList(),
        if (publisher != null) 'publisher': publisher!.toJson(),
      };
}

class AssetToken {
  AssetToken({
    required this.cid,
    required this.chain,
    required this.standard,
    required this.contractAddress,
    required this.tokenNumber,
    this.currentOwner,
    this.updatedAt,
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
  final DateTime? updatedAt;
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
        updatedAt: (json['updated_at'] != null)
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        metadata: json['metadata'] != null
            ? TokenMetadata.fromJson(
                Map<String, dynamic>.from(json['metadata'] as Map),
              )
            : null,
        owners: json['owners'] != null
            ? PaginatedOwners.fromJson(
                Map<String, dynamic>.from(json['owners'] as Map),
              )
            : null,
        provenanceEvents: json['provenance_events'] != null
            ? PaginatedProvenanceEvents.fromJson(
                Map<String, dynamic>.from(json['provenance_events'] as Map),
              )
            : null,
        enrichmentSource: json['enrichment_source'] != null
            ? EnrichmentSource.fromJson(
                Map<String, dynamic>.from(json['enrichment_source'] as Map),
              )
            : null,
        metadataMediaAssets: (json['metadata_media_assets'] as List?)
            ?.map(
                (e) => MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        enrichmentSourceMediaAssets: (json['enrichment_source_media_assets']
                as List?)
            ?.map(
                (e) => MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  factory AssetToken.fromRest(Map<String, dynamic> json) => AssetToken(
        cid: json['token_cid'] as String? ?? json['cid'] as String,
        chain: json['chain'] as String,
        standard: json['standard'] as String,
        contractAddress: json['contract_address'] as String,
        tokenNumber: json['token_number'] as String,
        currentOwner: json['current_owner'] as String?,
        updatedAt: (json['updated_at'] != null)
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        metadata: json['metadata'] != null
            ? TokenMetadata.fromJson(
                Map<String, dynamic>.from(json['metadata'] as Map),
              )
            : null,
        owners: json['owners'] != null
            ? PaginatedOwners.fromJson(
                Map<String, dynamic>.from(json['owners'] as Map),
              )
            : null,
        provenanceEvents: json['provenance_events'] != null
            ? PaginatedProvenanceEvents.fromJson(
                Map<String, dynamic>.from(json['provenance_events'] as Map),
              )
            : null,
        enrichmentSource: json['enrichment_source'] != null
            ? EnrichmentSource.fromJson(
                Map<String, dynamic>.from(json['enrichment_source'] as Map),
              )
            : null,
        metadataMediaAssets: (json['metadata_media_assets'] as List?)
            ?.map(
                (e) => MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        enrichmentSourceMediaAssets: (json['enrichment_source_media_assets']
                as List?)
            ?.map(
                (e) => MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Artist {
  Artist({required this.did, required this.name});

  final String did;
  final String name;

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        did: json['did'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'did': did,
        'name': name,
      };
}

class Publisher {
  Publisher({this.name, this.url});

  final String? name;
  final String? url;

  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
        name: json['name'] as String?,
        url: json['url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (url != null) 'url': url,
      };
}

class Owner {
  Owner({
    required this.ownerAddress,
    required this.quantity,
  });

  final String ownerAddress;
  final String quantity;

  factory Owner.fromJson(Map<String, dynamic> json) => Owner(
        ownerAddress: json['owner_address'] as String,
        quantity: json['quantity'] as String,
      );

  Map<String, dynamic> toJson() => {
        'owner_address': ownerAddress,
        'quantity': quantity,
      };
}

class PaginatedOwners {
  PaginatedOwners({required this.items});

  final List<Owner> items;

  factory PaginatedOwners.fromJson(Map<String, dynamic> json) =>
      PaginatedOwners(
        items: (json['items'] as List)
            .map((e) => Owner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class ProvenanceEvent {
  ProvenanceEvent({
    required this.chain,
    required this.eventType,
    this.fromAddress,
    this.toAddress,
    this.txHash,
    required this.timestamp,
  });

  final String chain;
  final String eventType;
  final String? fromAddress;
  final String? toAddress;
  final String? txHash;
  final DateTime timestamp;

  factory ProvenanceEvent.fromJson(Map<String, dynamic> json) =>
      ProvenanceEvent(
        chain: json['chain'] as String,
        eventType: json['event_type'] as String,
        fromAddress: json['from_address'] as String?,
        toAddress: json['to_address'] as String?,
        txHash: json['tx_hash'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'chain': chain,
        'event_type': eventType,
        if (fromAddress != null) 'from_address': fromAddress,
        if (toAddress != null) 'to_address': toAddress,
        if (txHash != null) 'tx_hash': txHash,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PaginatedProvenanceEvents {
  PaginatedProvenanceEvents({
    required this.items,
  });

  final List<ProvenanceEvent> items;

  factory PaginatedProvenanceEvents.fromJson(Map<String, dynamic> json) =>
      PaginatedProvenanceEvents(
        items: (json['items'] as List)
            .map((e) =>
                ProvenanceEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class EnrichmentSource {
  EnrichmentSource({
    required this.name,
    this.description,
    this.imageUrl,
    this.animationUrl,
    this.mimeType,
    this.artists,
  });

  final String name;
  final String? description;
  final String? imageUrl;
  final String? animationUrl;
  final String? mimeType;
  final List<Artist>? artists;

  factory EnrichmentSource.fromJson(Map<String, dynamic> json) =>
      EnrichmentSource(
        name: json['name'] as String,
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        animationUrl: json['animation_url'] as String?,
        mimeType: json['mime_type'] as String?,
        artists: (json['artists'] as List?)
            ?.map((e) => Artist.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        if (animationUrl != null) 'animation_url': animationUrl,
        if (mimeType != null) 'mime_type': mimeType,
        if (artists != null)
          'artists': artists!.map((a) => a.toJson()).toList(),
      };
}

class MediaAsset {
  MediaAsset({
    required this.sourceUrl,
    this.mimeType,
    required this.variantUrls,
  });

  final String sourceUrl;
  final String? mimeType;
  final Map<String, dynamic> variantUrls;

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        sourceUrl: json['source_url'] as String,
        mimeType: json['mime_type'] as String?,
        variantUrls: Map<String, dynamic>.from(json['variant_urls'] as Map),
      );

  Map<String, dynamic> toJson() => {
        'source_url': sourceUrl,
        if (mimeType != null) 'mime_type': mimeType,
        'variant_urls': variantUrls,
      };
}
