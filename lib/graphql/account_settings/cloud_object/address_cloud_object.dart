import 'dart:convert';

import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_object/base_cloud_object.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';

class WalletAddressCloudObject extends BaseCloudObject {
  WalletAddressCloudObject(CloudDB db) : super(db);

  Future<void> deleteAddress(WalletAddress address) async {
    // address is also the key
    await db.delete([address.key]);
  }

  WalletAddress? findByAddress(String address) {
    // address is also the key
    final value = db.query([address]);
    if (value.isEmpty) {
      return null;
    }
    final addressJson =
        jsonDecode(value.first['value']!) as Map<String, dynamic>;
    return WalletAddress.fromJson(addressJson);
  }

  List<WalletAddress> getAllAddresses() {
    final addresses = db.values
        .map((value) =>
            WalletAddress.fromJson(jsonDecode(value) as Map<String, dynamic>))
        .toList();
    return addresses;
  }

  Future<void> insertAddresses(List<WalletAddress> addresses,
      {OnConflict onConflict = OnConflict.override}) async {
    await db.write(addresses.map((address) => address.toKeyValue).toList(),
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
    await db.write(addresses.map((e) => e.toKeyValue).toList());
  }
}
