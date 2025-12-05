import 'package:autonomy_flutter/model/address.dart';
import 'package:autonomy_flutter/service/domain_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/eth_utils.dart';
import 'package:autonomy_flutter/util/xtz_utils.dart';
import 'package:web3dart/credentials.dart';

abstract class DomainAddressService {
  String? verifyEthereumAddress(String value);

  String? verifyTezosAddress(String value);

  Future<String?> verifyENS(String value);

  Future<String?> verifyTNS(String value);

  Future<Address?> verifyAddressOrDomain(String value);
}

class DomainAddressServiceImpl implements DomainAddressService {
  DomainAddressServiceImpl(this._domainService);

  final DomainService _domainService;

  Address? _verifyAddress(String value) {
    final ethAddress = verifyEthereumAddress(value);
    if (ethAddress != null) {
      return Address(address: ethAddress, type: CryptoType.ETH);
    }
    final tezosAddress = verifyTezosAddress(value);
    if (tezosAddress != null) {
      return Address(address: tezosAddress, type: CryptoType.XTZ);
    }
    return null;
  }

  Future<Address?> _verifyDomain(String value) async {
    final isENSFormat = value.isENSFormat();
    if (isENSFormat) {
      final ethAddress = await verifyENS(value);
      if (ethAddress != null) {
        final checksumAddress = verifyEthereumAddress(ethAddress);
        if (checksumAddress != null) {
          return Address(address: checksumAddress, type: CryptoType.ETH);
        }
      }
    } else if (value.isTNSFormat()) {
      final tezosAddress = await verifyTNS(value);
      if (tezosAddress != null) {
        final checksumAddress = verifyTezosAddress(tezosAddress);
        if (checksumAddress != null) {
          return Address(address: checksumAddress, type: CryptoType.XTZ);
        }
      }
    }
    return null;
  }

  @override
  String? verifyEthereumAddress(String address) {
    try {
      if (!address.isEthereumAddressFormat()) {
        return null;
      }
      final checksumAddress = EthereumAddress.fromHex(address).hexEip55;
      return checksumAddress;
    } catch (_) {
      return null;
    }
  }

  @override
  String? verifyTezosAddress(String address) {
    if (!address.isTezosAddressFormat()) {
      return null;
    }
    return address.isValidTezosAddress ? address : null;
  }

  @override
  Future<String?> verifyENS(String value) async {
    return _domainService.getAddress(value, cryptoType: CryptoType.ETH);
  }

  @override
  Future<String?> verifyTNS(String value) async {
    return _domainService.getAddress(value, cryptoType: CryptoType.XTZ);
  }

  @override
  Future<Address?> verifyAddressOrDomain(String value) async {
    final address = _verifyAddress(value);
    if (address != null) {
      return address;
    }
    return _verifyDomain(value);
  }
}
