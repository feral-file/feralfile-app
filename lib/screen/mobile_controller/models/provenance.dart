import 'package:autonomy_flutter/util/eth_utils.dart';

class DP1Provenance {
  DP1Provenance({
    required this.type,
    required this.contract,
  });

  // from json method
  factory DP1Provenance.fromJson(Map<String, dynamic> json) {
    return DP1Provenance(
      type: DP1ProvenanceType.fromString(json['type'] as String),
      contract: DP1Contract.fromJson(json['contract'] as Map<String, dynamic>),
    );
  }

  final DP1ProvenanceType type;
  final DP1Contract contract;

  // to json method
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'contract': contract.toJson(),
    };
  }
}

String getContractAddress(String address) {
  final ethereumAddress = address.toEthereumAddress(isChecksum: false);
  if (ethereumAddress != null) {
    return ethereumAddress.hexEip55;
  }
  return address;
}

class DP1Contract {
  DP1Contract({
    required this.chain,
    this.standard,
    this.address,
    this.tokenId,
    this.seriesId,
    this.uri,
    this.metaHash,
  }) : assert(
          (address != null && tokenId != null) || (seriesId != null),
        );

  //from json method
  factory DP1Contract.fromJson(Map<String, dynamic> json) {
    return DP1Contract(
      chain: DP1ProvenanceChain.fromString(json['chain'] as String),
      standard: json['standard'] != null
          ? DP1ProvenanceStandard.fromString(json['standard'] as String)
          : null,
      address: json['address'] as String?,
      tokenId: json['tokenId'] as String?,
      uri: json['uri'] as String?,
      seriesId: json['seriesId'] as String?,
      metaHash: json['metaHash'] as String?,
    );
  }

  final DP1ProvenanceChain chain;
  final DP1ProvenanceStandard? standard;
  final String? address;
  final String? tokenId;
  final String? seriesId;
  final String? uri;
  final String? metaHash;

  //to json method
  Map<String, dynamic> toJson() {
    return {
      'chain': chain.value,
      'standard': standard?.value,
      'address': address,
      'tokenId': tokenId,
      'uri': uri,
      'metaHash': metaHash,
    };
  }
}

enum DP1ProvenanceType {
  onChain,
  seriesRegistry,
  offChainURI;

  // from String
  static DP1ProvenanceType fromString(String value) {
    switch (value) {
      case 'onChain':
        return DP1ProvenanceType.onChain;
      case 'seriesRegistry':
        return DP1ProvenanceType.seriesRegistry;
      case 'offChainURI':
        return DP1ProvenanceType.offChainURI;
      default:
        throw ArgumentError('Unknown provenance type: $value');
    }
  }

  // to String
  String get value {
    switch (this) {
      case DP1ProvenanceType.onChain:
        return 'onChain';
      case DP1ProvenanceType.seriesRegistry:
        return 'seriesRegistry';
      case DP1ProvenanceType.offChainURI:
        return 'offChainURI';
    }
  }
}

enum DP1ProvenanceChain {
  evm,
  tezos,
  bitmark,
  other;

  // from string and to string
  static DP1ProvenanceChain fromString(String value) {
    switch (value) {
      case 'evm':
      case 'ethereum':
      case 'eth':
        return DP1ProvenanceChain.evm;
      case 'tezos':
      case 'tez':
        return DP1ProvenanceChain.tezos;
      case 'bitmark':
      case 'bmk':
        return DP1ProvenanceChain.bitmark;
      case 'other':
        return DP1ProvenanceChain.other;
      default:
        throw ArgumentError('Unknown provenance chain: $value');
    }
  }

  String get value {
    switch (this) {
      case DP1ProvenanceChain.evm:
        return 'evm';
      case DP1ProvenanceChain.tezos:
        return 'tezos';
      case DP1ProvenanceChain.bitmark:
        return 'bitmark';
      case DP1ProvenanceChain.other:
        return 'other';
    }
  }

  String get prefix {
    switch (this) {
      case DP1ProvenanceChain.evm:
        return 'eth';
      case DP1ProvenanceChain.tezos:
        return 'tez';
      case DP1ProvenanceChain.bitmark:
        return 'bmk';
      case DP1ProvenanceChain.other:
        return '';
    }
  }
}

enum DP1ProvenanceStandard {
  erc721,
  erc1155,
  fa2,
  other;

  // from String
  static DP1ProvenanceStandard fromString(String value) {
    switch (value) {
      case 'erc721':
        return DP1ProvenanceStandard.erc721;
      case 'erc1155':
        return DP1ProvenanceStandard.erc1155;
      case 'fa2':
        return DP1ProvenanceStandard.fa2;
      case 'other':
      default:
        return DP1ProvenanceStandard.other;
    }
  }

  // to String
  String get value {
    switch (this) {
      case DP1ProvenanceStandard.erc721:
        return 'erc721';
      case DP1ProvenanceStandard.erc1155:
        return 'erc1155';
      case DP1ProvenanceStandard.fa2:
        return 'fa2';
      case DP1ProvenanceStandard.other:
        return 'other';
    }
  }
}

extension DP1ContractExt on DP1Contract {
  String get indexId {
    final prefix = chain.prefix;
    final contractAddress = chain == DP1ProvenanceChain.bitmark ? '' : address;

    return '$prefix-$contractAddress-$tokenId';
  }
}

extension DP1ProvenanceExt on DP1Provenance {
  String get indexId => contract.indexId;
}
