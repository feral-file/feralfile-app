import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';

/// A high-level service to manage a user's DP1 playlists.
///
/// This service coordinates between the remote DP1 feed API (via DP1FeedService)
/// and local storage (via AppDataManager.dp1FeedStorageService).
class AddressIndexingInfo {
  AddressIndexingInfo({
    required this.address,
    required this.workflowId,
  });

  final String address;
  final String workflowId;

  Map<String, dynamic> toJson() => {
        'address': address,
        'workflow_id': workflowId,
      };

  factory AddressIndexingInfo.fromJson(Map<String, dynamic> json) =>
      AddressIndexingInfo(
        address: json['address'] as String,
        workflowId: json['workflow_id'] as String,
      );
}

class UserDp1PlaylistService {
  UserDp1PlaylistService();

  /*
  ------------------------------------------------------------
  ADDRESS INDEXING INFO
  ------------------------------------------------------------
  This is used to track indexing metadata (including workflowId) for each address.
  */

  Future<void> setAddressIndexingInfo({
    required List<AddressIndexingInfo> infos,
  }) async {
    await injector<ConfigurationService>().setAddressIndexingInfo(infos);
  }

  Future<void> updateAddressIndexingInfo({
    required List<AddressIndexingInfo> infos,
  }) async {
    final currentInfos =
        injector<ConfigurationService>().getAddressIndexingInfo();
    final byAddress = {
      for (final info in currentInfos) info.address: info,
    };

    for (final info in infos) {
      byAddress[info.address] = info;
    }

    await setAddressIndexingInfo(infos: byAddress.values.toList());
  }

  AddressIndexingInfo? getAddressIndexingInfo(String address) {
    final currentInfos =
        injector<ConfigurationService>().getAddressIndexingInfo();
    for (final info in currentInfos) {
      if (info.address == address) {
        return info;
      }
    }
    return null;
  }

  Future<void> clearAddressIndexingInfo({
    required List<String> addresses,
  }) async {
    final currentInfos =
        injector<ConfigurationService>().getAddressIndexingInfo();
    final filtered = currentInfos
        .where((info) => !addresses.contains(info.address))
        .toList();
    await setAddressIndexingInfo(infos: filtered);
  }

  bool isAddressIndexed(String address) {
    final info = getAddressIndexingInfo(address);
    return info != null && info.workflowId.isNotEmpty;
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
    await setAddressIndexingInfo(infos: <AddressIndexingInfo>[]);
    await setAddressLastFetchTokenTime(addresses: {});
    await setLastUpdateChangeAnchor(addressAnchors: []);
  }
}
