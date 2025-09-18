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
  query getTokens($owners: [String!]! = [],$ids: [String!]! = [], $size: Int64! = 50, $lastUpdatedAt: Time, $offset: Int64! = 0, $burnedIncluded: Boolean! = false) {
  tokens(owners: $owners,ids: $ids, size: $size, lastUpdatedAt: $lastUpdatedAt, offset: $offset, burnedIncluded: $burnedIncluded) {
    id
    blockchain
    fungible
    contractType
    contractAddress
    edition
    editionName
    mintedAt
    balance
    owner
    owners {
      address
      balance
    }
    indexID
    source
    swapped
    burned
    lastActivityTime
    originTokenInfo {
      id
      blockchain
      fungible
      contractType
      contractAddress
    }
    provenance {
      type
      owner
      blockchain
      blockNumber
      timestamp
      txID
      txURL
    }
    lastRefreshedTime
    asset{
      indexID
      thumbnailID
      lastRefreshedTime
      attributes{
        configuration {
          scaling
          backgroundColor
          marginLeft
          marginRight
          marginTop
          marginBottom
          autoPlay
          looping
          interactable
          overridable
        }
      }
      metadata{
        project{
          origin{
            artistID
            artistName
            artistURL
            artists{
            name
            id
            url
            }
            assetID
            title
            description
            mimeType
            medium
            maxEdition
            baseCurrency
            basePrice
            source
            sourceURL
            previewURL
            thumbnailURL
            galleryThumbnailURL
            assetData
            assetURL
            artworkMetadata
          }
          latest{
            artistID
            artistName
            artistURL
            artists{
            name
            id
            url
            }
            assetID
            title
            description
            mimeType
            medium
            maxEdition
            baseCurrency
            basePrice
            source
            sourceURL
            previewURL
            thumbnailURL
            galleryThumbnailURL
            assetData
            assetURL
            artworkMetadata
          }
        }
      }
    }

  }
}
''';

const String getCompactedTokens = r'''
  query getCompactedTokens($owners: [String!]! = [],$ids: [String!]! = [], $size: Int64! = 50, $lastUpdatedAt: Time, $offset: Int64! = 0, $burnedIncluded: Boolean! = false) {
  tokens(owners: $owners,ids: $ids, size: $size, lastUpdatedAt: $lastUpdatedAt, offset: $offset, burnedIncluded: $burnedIncluded) {
    id
    blockchain
    edition
    editionName
    mintedAt
    balance
    owner
    owners {
      address
      balance
    }
    indexID
    lastActivityTime
    lastRefreshedTime
    asset{
      indexID
      thumbnailID
      lastRefreshedTime
      metadata{
        project{
          latest{
            artistID
            artistName
            artistURL
            artists{
            name
            id
            url
            }
            assetID
            title
            description
            mimeType
            medium
            maxEdition
            baseCurrency
            basePrice
            source
            sourceURL
            previewURL
            thumbnailURL
            galleryThumbnailURL
            assetData
            assetURL
            artworkMetadata
          }
        }
      }
    }
  }
}
''';

const String getColectionTokenQuery = r'''
query getCollectionToken($collectionID: String!,
$offset: Int64! = 0,
    $size: Int64! = 50) {
  tokens(
    collectionID: $collectionID,
    offset: $offset,
    size: $size,
  ) {
    id
    blockchain
    fungible
    contractType
    contractAddress
    edition
    editionName
    mintedAt
    balance
    owner
    owners {
      address
      balance
    }
    indexID
    source
    swapped
    burned
    lastActivityTime
    originTokenInfo {
      id
      blockchain
      fungible
      contractType
      contractAddress
    }
    provenance {
      type
      owner
      blockchain
      blockNumber
      timestamp
      txID
      txURL
    }
    lastRefreshedTime
    asset{
      indexID
      thumbnailID
      lastRefreshedTime
      attributes{
        configuration {
          scaling
          backgroundColor
          marginLeft
          marginRight
          marginTop
          marginBottom
          autoPlay
          looping
          overridable
        }
      }
      metadata{
        project{
          origin{
            artistID
            artistName
            artistURL
            artists{
            name
            id
            url
            }
            assetID
            title
            description
            mimeType
            medium
            maxEdition
            baseCurrency
            basePrice
            source
            sourceURL
            previewURL
            thumbnailURL
            galleryThumbnailURL
            assetData
            assetURL
            artworkMetadata
          }
          latest{
            artistID
            artistName
            artistURL
            artists{
            name
            id
            url
            }
            assetID
            title
            description
            mimeType
            medium
            maxEdition
            baseCurrency
            basePrice
            source
            sourceURL
            previewURL
            thumbnailURL
            galleryThumbnailURL
            assetData
            assetURL
            artworkMetadata
          }
        }
      }
    }
  }
}
''';

const String getTokenConfigurations = r'''
  query getTokensConfigurations($tokenId: String!) {
  tokens(ids: [$tokenId]) {
    asset {
      attributes {
        configuration {
          scaling
          backgroundColor
          marginLeft
          marginRight
          marginTop
          marginBottom
          autoPlay
          looping
          interactable
          overridable
        }
      }
    }
  }
}
''';

// query documents to query tokens by owners
