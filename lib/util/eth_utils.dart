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

  /// Check if the string is an Ethereum address format
  bool isEthereumAddressFormat() {
    final regex = RegExp(r'^(0x[a-fA-F0-9]{40})$');
    return regex.hasMatch(this);
  }

  /// Check if the string is an ENS format (Ethereum Name Service)
  bool isENSFormat() {
    final regex = RegExp(r'^[^\s]+\.eth$', caseSensitive: false);
    return regex.hasMatch(this);
  }

  bool isValidEthereumAddress() {
    if (!isEthereumAddressFormat()) {
      return false;
    }

    return isEthereumAddressFormat();
  }
}
