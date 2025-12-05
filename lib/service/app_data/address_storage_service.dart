import 'dart:convert';

import 'package:autonomy_flutter/database/hive_storage_service.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';

class AddressStorageService extends HiveStorageService {
  AddressStorageService(super.db, super._prefix);

  Future<void> deleteAddress(WalletAddress address) async {
    // address is also the key
    await delete([address.key]);
  }

  WalletAddress? findByAddress(String address) {
    // address is also the key
    final value = query([address]);
    if (value.isEmpty) {
      return null;
    }
    final addressJson =
        jsonDecode(value.first['value']!) as Map<String, dynamic>;
    return WalletAddress.fromJson(addressJson);
  }

  List<WalletAddress> getAllAddresses() {
    final addresses = values
        .map(
          (value) =>
              WalletAddress.fromJson(jsonDecode(value) as Map<String, dynamic>),
        )
        .toList();
    return addresses;
  }

  WalletAddress? getWalletAddress(String address) {
    final addresses = getAllAddresses();
    return addresses.where((element) => element.address == address).firstOrNull;
  }

  Future<void> insertAddresses(List<WalletAddress> addresses,
      {OnConflict onConflict = OnConflict.override}) async {
    await write(addresses.map((address) => address.toKeyValue).toList(),
        onConflict: onConflict);
  }

  Future<void> setAddressIsHidden(String address, bool isHidden) async {
    final walletAddress = findByAddress(address);
    if (walletAddress == null) {
      return;
    }
    await updateAddresses([walletAddress.copyWith(isHidden: isHidden)]);
  }

  Future<void> updateAddresses(List<WalletAddress> addresses) async {
    await write(addresses.map((e) => e.toKeyValue).toList());
  }
}
