import 'package:web3dart/credentials.dart';

extension EthereumExtension on String {
  // to ethereum address
  EthereumAddress? toEthereumAddress({bool isChecksum = false}) {
    try {
      final address = EthereumAddress.fromHex(this, enforceEip55: isChecksum);
      return address;
    } catch (_) {
      return null;
    }
  }

  bool get isNullAddress {
    return this == '0x0000000000000000000000000000000000000000';
  }
}
