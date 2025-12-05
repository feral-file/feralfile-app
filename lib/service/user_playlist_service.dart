import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';

/// A high-level service to manage a user's DP1 playlists.
///
/// This service coordinates between the remote DP1 feed API (via DP1FeedService)
/// and local storage (via AppDataManager.dp1FeedStorageService).
class UserDp1PlaylistService {
  UserDp1PlaylistService();

  /*
  ------------------------------------------------------------
  ADDRESS LAST INDEX TIME
  ------------------------------------------------------------
  This is used to track the last index time for each address.
  */

  Future<void> setAddressLastIndexTime({
    required Map<String, DateTime> addresses,
  }) async {
    await injector<ConfigurationService>().setAddressLastIndexTime(addresses);
  }

  Future<void> updateAddressLastIndexTime({
    required Map<String, DateTime?> addresses,
  }) async {
    final addressLastRefreshedTime =
        injector<ConfigurationService>().getAddressLastIndexTime();
    // update the time for the addresses
    for (final entry in addresses.entries) {
      if (entry.value == null) {
        addressLastRefreshedTime.remove(entry.key);
      } else {
        final candidate = entry.value!.toUtc();
        final current = addressLastRefreshedTime[entry.key];
        if (current == null || candidate.isAfter(current)) {
          addressLastRefreshedTime[entry.key] = candidate;
        } else {
          addressLastRefreshedTime[entry.key] = current;
        }
      }
    }
    await setAddressLastIndexTime(addresses: addressLastRefreshedTime);
  }

  Map<String, DateTime?> getAddressOldestLastIndexTime({
    required List<String> addresses,
  }) {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    final result = <String, DateTime?>{};
    for (final addr in addresses) {
      result[addr] = map[addr];
    }
    return result;
  }

  Future<void> clearAddressLastIndexTime({
    required List<String> addresses,
  }) async {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    for (final addr in addresses) {
      map.remove(addr);
    }
    await setAddressLastIndexTime(addresses: map);
  }

  bool isAddressIndexed(String address) {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    return map.containsKey(address);
  }

  /*
  ------------------------------------------------------------
  ADDRESS LAST FETCH TOKEN TIME
  ------------------------------------------------------------
  This is used to track the last fetch token time for each address.
  */
  Future<void> setAddressLastFetchTokenTime({
    required Map<String, DateTime> addresses,
  }) async {
    await injector<ConfigurationService>()
        .setAddressLastFetchTokenTime(addresses);
  }

  Future<void> updateAddressLastFetchTokenTime({
    required Map<String, DateTime?> addresses,
  }) async {
    final addressLastFetchTokenTime =
        injector<ConfigurationService>().getAddressLastFetchTokenTime();
    // update the time for the addresses
    for (final entry in addresses.entries) {
      if (entry.value == null) {
        addressLastFetchTokenTime.remove(entry.key);
      } else {
        final candidate = entry.value!.toUtc();
        final current = addressLastFetchTokenTime[entry.key];
        if (current == null || candidate.isAfter(current)) {
          addressLastFetchTokenTime[entry.key] = candidate;
        } else {
          addressLastFetchTokenTime[entry.key] = current;
        }
      }
    }
    await setAddressLastFetchTokenTime(addresses: addressLastFetchTokenTime);
  }

  Map<String, DateTime?> getAddressOldestLastFetchTokenTime({
    required List<String> addresses,
  }) {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    final result = <String, DateTime?>{};
    for (final addr in addresses) {
      result[addr] = map[addr];
    }
    return result;
  }

  Future<void> clearAddressLastFetchTokenTime({
    required List<String> addresses,
  }) async {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    for (final addr in addresses) {
      map.remove(addr);
    }
    await setAddressLastFetchTokenTime(addresses: map);
  }

  bool isAddressFetched(String address) {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    return map.containsKey(address);
  }

  /*
  ------------------------------------------------------------
  ADDRESS ANCHOR
  ------------------------------------------------------------
  This is used to track the last update change anchor for each address.
   */

  List<AddressAnchor> getLastUpdateChangeAnchor(
      {required List<String> addresses,
      AddressAnchor Function(String address)? defaultAnchorBuilder}) {
    return injector<ConfigurationService>().getLastUpdateChangeAnchor(
        addresses: addresses, defaultAnchorBuilder: defaultAnchorBuilder);
  }

  Future<void> setLastUpdateChangeAnchor(
      {required List<AddressAnchor> addressAnchors}) async {
    await injector<ConfigurationService>()
        .setLastUpdateChangeAnchor(addressAnchors: addressAnchors);
  }

  Future<void> updateLastUpdateChangeAnchor(
      {required List<AddressAnchor> addressAnchors}) async {
    final currentAnchor = getLastUpdateChangeAnchor(
        addresses: addressAnchors.map((e) => e.address).toList());
    for (final anchor in addressAnchors) {
      if (currentAnchor.any((e) => e.address == anchor.address)) {
        currentAnchor.removeWhere((e) => e.address == anchor.address);
      }
    }
    currentAnchor.addAll(addressAnchors);
    await injector<ConfigurationService>()
        .setLastUpdateChangeAnchor(addressAnchors: currentAnchor);
  }

  Future<void> removeLastUpdateChangeAnchor(
      {required List<String> addresses}) async {
    final currentAnchor = getLastUpdateChangeAnchor(addresses: addresses);
    currentAnchor.removeWhere((anchor) => addresses.contains(anchor.address));
    await setLastUpdateChangeAnchor(addressAnchors: currentAnchor);
  }

  Future<void> clearData() async {
    // await injector<ConfigurationService>().clearAddressLastRefreshedTime();
    await setAddressLastIndexTime(addresses: {});
    await setAddressLastFetchTokenTime(addresses: {});
    await setLastUpdateChangeAnchor(addressAnchors: []);
  }
}
