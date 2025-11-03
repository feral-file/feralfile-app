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
  query getTokens($owners: [String!]!) {
    tokens(
      owner: $owners
      expand: [
        "provenance_events",
        "owners",
        "metadata_media_asset",
        "enrichment_source_media_asset",
        "enrichment_source"
      ]
      provenance_events_order: desc
    ) {
      items {
        id
        chain
        contract_address
        standard
        token_cid
        token_number
        current_owner
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
      offset
      total
    }
  }
''';
