/*
type Token {
  	id:             	String!
	blockchain:      	String!
	fungible:        	Boolean!
	contractType:    	String!
	contractAddress:	String!

  	edition:         	Int64!
	editionName:     	String!
	mintedAt:          	Time
	balance:         	Int64!
	owner:           	String!

	indexID:         	String!
	source:          	String!
	swapped:         	Boolean!
	burned:          	Boolean!
	provenance:			[Provenance!]!
	attributes: 		AssetAttributes
	lastActivityTime:  	Time
	lastRefreshedTime: 	Time
  	asset:           	Asset!
}

type Provenance {
	type:        String!
	owner:       String!
	blockchain:  String!
	blockNumber: Int64
	timestamp:   Time
	txID:        String!
	txURL:       String!
}

type AssetAttributes {
	configuration: ArtistDisplaySetting
}

type Asset {
	indexID:       		String!
	thumbnailID:   		String!
	lastRefreshedTime:	Time
	metadata:      		AssetMetadata!
}

type AssetMetadata {
  	project:  VersionedProjectMetadata!
}

type VersionedProjectMetadata {
  	origin:   ProjectMetadata!
  	latest:  ProjectMetadata!
}

type ProjectMetadata {
	artistID:            String!
	artistName:          String!
	artistURL:           String!
	assetID:             String!
	title:               String!
	description:         String!
	mimeType:            String!
	medium:              String!
	maxEdition:          Int64!
	baseCurrency:        String!
	basePrice:           Int64!
	source:              String!
	sourceURL:           String!
	previewURL:          String!
	thumbnailURL:        String!
	galleryThumbnailURL: String!
	assetData:           String!
	assetURL:            String!
}

type Identity {
	accountNumber:  String!
	blockchain:      String!
	name:            String!
}

type Query {
  tokens(owners: [String!]! = [], ids: [String!]! = [], lastUpdatedAt: Time, offset: Int64! = 0, size: Int64! = 50): [Token!]!
  identity(account: String!): Identity
}
 */

const String getTokens = r'''
  query getTokens(
    $owners: [String!]
    $chains: [String!]
    $contract_addresses: [String!]
    $token_ids: [Uint64!]
    $token_cids: [String!]
    $token_numbers: [String!]
    $limit: Uint8 = 20
    $offset: Uint64 = 0
    $expands: [String!]
    $owners_limit: Uint8 = 10
    $owners_offset: Uint64 = 0
    $provenance_events_limit: Uint8 = 10
    $provenance_events_offset: Uint64 = 0
    $provenance_events_order: Order = desc
  ) {
    tokens(
      owners: $owners
      chains: $chains
      contract_addresses: $contract_addresses
      token_ids: $token_ids
      token_cids: $token_cids
      token_numbers: $token_numbers
      limit: $limit
      offset: $offset
      expands: $expands
      owners_limit: $owners_limit
      owners_offset: $owners_offset
      provenance_events_limit: $provenance_events_limit
      provenance_events_offset: $provenance_events_offset
      provenance_events_order: $provenance_events_order
    ) {
      items {
        id
        chain
        contract_address
        standard
        token_cid
        token_number
        current_owner
        updated_at
        metadata {
          name
          description
          image_url
          animation_url
          mime_type
          artists {
            name
            did
          }
          publisher {
            name
            url
          }
        }
        owners {
          items {
            quantity
            owner_address
          }
          total
          offset
        }
        provenance_events {
          items {
            event_type
            from_address
            to_address
            tx_hash
            timestamp
            chain
          }
          total
          offset
        }
        enrichment_source {
          name
          description
          image_url
          animation_url
          mime_type
          artists {
            name
            did
          }
        }
        metadata_media_assets {
          source_url
          mime_type
          variant_urls
        }
        enrichment_source_media_assets {
          source_url
          mime_type
          variant_urls
        }
      }
      offset
      total
    }
  }
''';

const String getTokenByCidQuery = r'''
  query getToken(
    $cid: String!
    $expands: [String!]
    $owners_limit: Uint8 = 10
    $owners_offset: Uint64 = 0
    $provenance_events_limit: Uint8 = 10
    $provenance_events_offset: Uint64 = 0
    $provenance_events_order: Order = desc
  ) {
    token(
      cid: $cid
      expands: $expands
      owners_limit: $owners_limit
      owners_offset: $owners_offset
      provenance_events_limit: $provenance_events_limit
      provenance_events_offset: $provenance_events_offset
      provenance_events_order: $provenance_events_order
    ) {
      id
      chain
      contract_address
      standard
      token_cid
      token_number
      current_owner
      updated_at
      metadata {
        name
        description
        image_url
        animation_url
        mime_type
        artists {
          name
          did
        }
        publisher {
          name
          url
        }
      }
      owners {
        items {
          quantity
          owner_address
        }
      }
      provenance_events {
        items {
          event_type
          from_address
          to_address
          tx_hash
          timestamp
          chain
        }
      }
      enrichment_source {
        name
        description
        image_url
        animation_url
        mime_type
        artists {
          name
          did
        }
      }
      metadata_media_assets {
        source_url
        mime_type
        variant_urls
      }
      enrichment_source_media_assets {
        source_url
        mime_type
        variant_urls
      }
    }
  }
''';

const String getTokenWithOwnersAndProvenanceQuery = r'''
  query getToken(
    $cid: String!
    $owners_limit: Uint8 = 255
    $owners_offset: Uint64 = 0
    $provenance_events_limit: Uint8 = 255
    $provenance_events_offset: Uint64 = 0
    $provenance_events_order: Order = desc
  ) {
    token(
      cid: $cid
      provenance_events_order: $provenance_events_order
      provenance_events_limit: $provenance_events_limit
      provenance_events_offset: $provenance_events_offset
      owners_offset: $owners_offset
      owners_limit: $owners_limit
    ) {
      id
      token_cid
      owners {
        items {
          quantity
          owner_address
        }
        total
        offset
      }
      provenance_events {
        items {
          event_type
          from_address
          to_address
          tx_hash
          timestamp
          chain
        }
        total
        offset
      }
    }
  }
''';
