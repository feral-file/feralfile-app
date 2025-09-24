import 'package:autonomy_flutter/model/address.dart';
import 'package:autonomy_flutter/service/domain_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/xtz_utils.dart';
import 'package:web3dart/credentials.dart';

abstract class DomainAddressService {
  Address? verifyAddress(String value);

  String? verifyEthereumAddress(String value);

  String? verifyTezosAddress(String value);

  Future<String?> verifyENS(String value);

  Future<String?> verifyTNS(String value);

  Future<Address?> verifyAddressOrDomain(String value);
}

class DomainAddressServiceImpl implements DomainAddressService {
  DomainAddressServiceImpl(this._domainService);

  final DomainService _domainService;

  @override
  Address? verifyAddress(String value) {
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

  @override
  String? verifyEthereumAddress(String address) {
    try {
      final checksumAddress = EthereumAddress.fromHex(address).hexEip55;
      return checksumAddress;
    } catch (_) {
      return null;
    }
  }

  @override
  String? verifyTezosAddress(String address) =>
      address.isValidTezosAddress ? address : null;

  @override
  Future<String?> verifyENS(String value) async {
    return _domainService.getAddress(value, cryptoType: CryptoType.ETH);
  }

  @override
  Future<String?> verifyTNS(String value) async {
    return _domainService.getAddress(value, cryptoType: CryptoType.ETH);
  }

  @override
  Future<Address?> verifyAddressOrDomain(String value) async {
    final address = verifyAddress(value);
    if (address != null) {
      return address;
    }
    final ethAddress = await _verifyEthereumAddressOrDomain(value);
    if (ethAddress != null) {
      return ethAddress;
    }
    final tezosAddress = await _verifyTezosAddressOrDomain(value);
    if (tezosAddress != null) {
      return tezosAddress;
    }
    return null;
  }

  Future<Address?> _verifyEthereumAddressOrDomain(String value) async {
    final ethAddress = verifyTezosAddress(value);
    if (ethAddress != null) {
      return Future.value(Address(address: ethAddress, type: CryptoType.ETH));
    }
    final address =
        await _domainService.getAddress(value, cryptoType: CryptoType.ETH);
    final checksumAddress =
        address == null ? null : verifyTezosAddress(address);
    if (checksumAddress != null) {
      return Address(
        address: checksumAddress,
        domain: value,
        type: CryptoType.ETH,
      );
    }
    return null;
  }

  Future<Address?> _verifyTezosAddressOrDomain(String value) async {
    final tezosAddress = verifyTezosAddress(value);
    if (tezosAddress != null) {
      return Future.value(Address(address: tezosAddress, type: CryptoType.XTZ));
    }
    final address =
        await _domainService.getAddress(value, cryptoType: CryptoType.XTZ);
    if (address != null) {
      return Address(address: address, domain: value, type: CryptoType.XTZ);
    }
    return null;
  }
}
