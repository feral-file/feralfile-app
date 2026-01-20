import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/dp1/dp1_manifest.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_item_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';

import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as db;

extension DP1NowDisplayingItemExt on DP1NowDisplayingItem {
  /// Get the best available thumbnail from the manifest, or null if not present
  DP1Thumbnail? get thumbnail {
    DP1Thumbnail? thumb;
    thumb = dp1Manifest?.getThumbnail('small');
    if (thumb != null) return thumb;

    final thumbnailUrl = assetToken?.getGalleryThumbnailUrl();
    if (thumbnailUrl != null) {
      thumb = DP1Thumbnail(uri: thumbnailUrl);
    }

    return thumb;
  }

  /// Get the effective title from the manifest, using the preferred locale if available
  String? get title {
    // If there is a preferred locale in DP1NowDisplayingItem, use it; otherwise fall back to default
    // This assumes DP1NowDisplayingItem has a preferredLocale property, otherwise just use manifest?.metadata?.title
    return dp1Item.title ?? assetToken?.displayTitle;
  }

  /// Get list of artist names from the manifest
  List<DP1Artist> get artists {
    final manifestArtists = dp1Manifest?.metadata?.artists;
    if (manifestArtists != null) {
      return manifestArtists;
    }

    final artists = assetToken?.getArtists
        .map((e) => DP1Artist(name: e.name, url: null, id: e.did))
        .toList();
    return artists ?? [];
  }

  bool get canInteract {
    return assetToken != null && assetToken!.canInteract;
  }

  static DP1NowDisplayingItem fromItemRow(db.Item itemRow) {
    AssetToken? assetToken;
    try {
      assetToken = AssetToken.fromRest(
        jsonDecode(itemRow.tokenDataJson!) as Map<String, dynamic>,
      );
    } catch (e) {
      log.info('Error in fromItemRow: $e');
      unawaited(Sentry.captureException(e));
    }
    final dp1Item = DP1PlaylistItemExtension.fromItemRow(itemRow);
    return DP1NowDisplayingItem(dp1Item: dp1Item, assetToken: assetToken);
  }
}

extension DP1NowDisplayingItemListExt on List<DP1NowDisplayingItem> {
  /// Check if this list is equal to another list of DP1NowDisplayingItem.
  /// Compares by CID and assetToken data.
  bool isEqual(List<DP1NowDisplayingItem> other) {
    if (length != other.length) {
      return false;
    }

    for (var i = 0; i < length; i++) {
      final currentItem = this[i];
      final updatedItem = other[i];

      // Compare CID
      if (currentItem.dp1Item.cid != updatedItem.dp1Item.cid) {
        return false;
      }

      // Compare assetToken - check if both are null or both have same CID
      final currentTokenCid = currentItem.assetToken?.cid;
      final updatedTokenCid = updatedItem.assetToken?.cid;
      if (currentTokenCid != updatedTokenCid) {
        return false;
      }

      // If both have tokens, compare updatedAt to detect data changes
      if (currentTokenCid != null && updatedTokenCid != null) {
        final currentUpdatedAt = currentItem.assetToken?.updatedAt;
        final updatedUpdatedAt = updatedItem.assetToken?.updatedAt;
        if (currentUpdatedAt != updatedUpdatedAt) {
          return false;
        }
      }
    }

    return true;
  }

  /// Build nowDisplayingItems from DP1Items and AssetTokens.
  /// Maps tokens to items by CID for static playlists.
  static List<DP1NowDisplayingItem> buildFromTokens(
    List<DP1Item> items,
    List<AssetToken> tokens,
  ) {
    final nowDisplayingItems = <DP1NowDisplayingItem>[];

    // For static playlists, map tokens to items by CID
    for (final dp1Item in items) {
      final assetToken = tokens.firstWhereOrNull((e) => e.cid == dp1Item.cid);
      nowDisplayingItems.add(
        DP1NowDisplayingItem(dp1Item: dp1Item, assetToken: assetToken),
      );
    }

    return nowDisplayingItems;
  }

  /// Build nowDisplayingItems for playlist with pagination.
  /// Handles both static playlists (with items) and dynamic playlists (with dynamicQuery).
  static Future<List<DP1NowDisplayingItem>> buildFromPlaylist({
    required DP1Call playlist,
    required int offset,
    required int size,
  }) async {
    final isStatic = playlist.items.isNotEmpty;
    if (isStatic) {
      return _buildFromStaticItems(
        playlist: playlist,
        offset: offset,
        size: size,
      );
    } else {
      return _buildFromDynamicQuery(
        playlist: playlist,
        offset: offset,
        size: size,
      );
    }
  }

  /// Build nowDisplayingItems for playlist with static items.
  static Future<List<DP1NowDisplayingItem>> _buildFromStaticItems({
    required DP1Call playlist,
    required int offset,
    required int size,
  }) async {
    final items = playlist.items;
    final pageItems = items.safeSublist(offset, offset + size);
    if (pageItems.isEmpty) {
      return [];
    }

    final nowDisplayingItems = <DP1NowDisplayingItem>[];

    final pageIds =
        pageItems.map((item) => item.id).whereType<String>().toList();
    try {
      final localDp1Items =
          await injector<DriftDatabaseService>().getItemsByIds(pageIds);
      final localNowDisplayingItems = localDp1Items
          .map((item) => DP1NowDisplayingItemExt.fromItemRow(item))
          .toList();
      nowDisplayingItems.addAll(localNowDisplayingItems);
    } catch (e) {
      log.info('Error getting tokens: $e');
      unawaited(Sentry.captureException(e));
      return [];
    }

    // if the items are missing in the database, add them to the list
    // final missingItems = pageItems
    //     .where(
    //         (item) => !nowDisplayingItems.any((e) => e.dp1Item.cid == item.cid))
    //     .toList();
    // if (missingItems.isNotEmpty) {
    //   final missingCid = missingItems.map((item) => item.cid).nonNulls.toList();
    //   final missingAssetTokens =
    //       await injector<NftTokensService>().getManualTokens(cids: missingCid);
    //   final missingNowDisplayingItems =
    //       buildFromTokens(missingItems, missingAssetTokens);
    //   nowDisplayingItems.addAll(missingNowDisplayingItems);
    // }

    return nowDisplayingItems;
  }

  /// Build nowDisplayingItems for playlist with dynamic query (owners-based).
  static Future<List<DP1NowDisplayingItem>> _buildFromDynamicQuery({
    required DP1Call playlist,
    required int offset,
    required int size,
  }) async {
    log.info(
      '[DP1NowDisplayingItemListExt][_buildFromDynamicQuery] Fetching items from Drift for playlist ${playlist.id}, offset: $offset, size: $size',
    );

    final start = DateTime.now();
    // Fetch all indexer-backed items for this playlist from Drift.
    // These items were previously ingested from indexer tokens and
    // have [tokenDataJson] populated.
    final pageItems =
        await injector<DriftDatabaseService>().getItemsByPlaylistId(
      playlist.id,
      type: DriftItemKind.indexerToken,
      offset: offset,
      size: size,
    );

    if (pageItems.isEmpty) {
      log.info(
        '[DP1NowDisplayingItemListExt][_buildFromDynamicQuery] No Drift items found for playlist ${playlist.id}',
      );
      return <DP1NowDisplayingItem>[];
    }

    // Apply pagination on the ordered list coming from Drift.

    final nowDisplayingItems = <DP1NowDisplayingItem>[];

    for (final item in pageItems) {
      // Reconstruct AssetToken from stored JSON; if missing or invalid,
      // skip this entry but keep processing the rest.
      if (item.tokenDataJson == null || item.tokenDataJson!.isEmpty) {
        continue;
      }

      try {
        final tokenMap =
            json.decode(item.tokenDataJson!) as Map<String, dynamic>;
        final assetToken = AssetToken.fromRest(tokenMap);

        final dp1Item = DP1PlaylistItemExtension.fromAssetToken(
          token: assetToken,
        );

        nowDisplayingItems.add(
          DP1NowDisplayingItem(
            dp1Item: dp1Item,
            assetToken: assetToken,
          ),
        );
      } catch (e, st) {
        log.info(
          '[DP1NowDisplayingItemListExt][_buildFromDynamicQuery] Error decoding tokenDataJson for item ${item.id}: $e',
        );
        unawaited(Sentry.captureException(e, stackTrace: st));
      }
    }

    log.info(
      '[DP1NowDisplayingItemListExt][_buildFromDynamicQuery] Returning ${nowDisplayingItems.length} items for playlist ${playlist.id} in ${DateTime.now().difference(start).inMilliseconds}ms',
    );
    return nowDisplayingItems;
  }
}
