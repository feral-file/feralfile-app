import 'dart:convert';

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as db;
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/log.dart';

extension DP1PlaylistItemExtension on DP1Item {
  static DP1Item fromAssetToken({
    required AssetToken token,
    Duration duration = Duration.zero,
    ArtworkDisplayLicense license = ArtworkDisplayLicense.open,
  }) {
    final dp1Contract = DP1Contract(
        chain: DP1ProvenanceChain.fromBlockchain(token.blockchain),
        standard: DP1ProvenanceStandard.fromString(token.standard),
        address: token.contractAddress,
        tokenId: token.tokenNumber);
    final dp1Provenance =
        DP1Provenance(type: DP1ProvenanceType.onChain, contract: dp1Contract);
    return DP1Item(
      id: token.cid,
      title: token.displayTitle,
      source: token.getPreviewUrl(),
      duration: duration.inSeconds,
      license: license,
      provenance: dp1Provenance,
    );
  }

  static DP1Item fromItemRow(db.Item item) {
    try {
      final display = item.displayJson != null && item.displayJson!.isNotEmpty
          ? DP1PlaylistDisplay.fromJson(
              json.decode(item.displayJson!) as Map<String, dynamic>)
          : null;
      final repro = item.reproJson != null && item.reproJson!.isNotEmpty
          ? ReproBlock.fromJson(
              json.decode(item.reproJson!) as Map<String, dynamic>)
          : null;
      final provenance =
          item.provenanceJson != null && item.provenanceJson!.isNotEmpty
              ? DP1Provenance.fromJson(
                  json.decode(item.provenanceJson!) as Map<String, dynamic>)
              : null;
      return DP1Item(
          id: item.id,
          title: item.title,
          source: item.sourceUri ?? item.thumbnailUri,
          duration: item.durationSec ?? 0,
          license: ArtworkDisplayLicense.fromString(item.license ?? 'open'),
          ref: item.refUri,
          display: display,
          repro: repro,
          provenance: provenance);
    } catch (e) {
      log.info('Error in fromItemRow: $e');
      rethrow;
    }
  }
}

/// Utility class for DP1Item operations
class DP1ItemUtils {
  /// Generate item ID for indexer tokens
  /// Format: 'indexer_token_{token.cid}'
  static String generateItemIdFromToken(
      AssetToken token, String? ownerAddress) {
    return '${token.cid}_${ownerAddress?.toUpperCase()}';
  }

  static String generateItemIdFromCid(String cid, String? ownerAddress) {
    return '${cid}_${ownerAddress?.toUpperCase()}';
  }
}

/// Extension on [DP1Item] to create from database [db.Item]
extension DP1ItemExtension on DP1Item {
  /// Create [DP1Item] from [db.Item] row
  ///
  /// Parses JSON fields (provenance, repro, display) if present
  /// and maps database fields to DP1Item structure.
  static DP1Item fromItemRow(db.Item item) {
    // Parse provenance from JSON if available
    DP1Provenance? provenance;
    if (item.provenanceJson != null && item.provenanceJson!.isNotEmpty) {
      try {
        final provenanceMap =
            json.decode(item.provenanceJson!) as Map<String, dynamic>;
        provenance = DP1Provenance.fromJson(provenanceMap);
      } catch (e) {
        // If parsing fails, leave provenance as null
      }
    }

    // Parse repro from JSON if available
    ReproBlock? repro;
    if (item.reproJson != null && item.reproJson!.isNotEmpty) {
      try {
        final reproMap = json.decode(item.reproJson!) as Map<String, dynamic>;
        repro = ReproBlock.fromJson(reproMap);
      } catch (e) {
        // If parsing fails, leave repro as null
      }
    }

    // Parse display from JSON if available
    DP1PlaylistDisplay? display;
    if (item.displayJson != null && item.displayJson!.isNotEmpty) {
      try {
        final displayMap =
            json.decode(item.displayJson!) as Map<String, dynamic>;
        display = DP1PlaylistDisplay.fromJson(displayMap);
      } catch (e) {
        // If parsing fails, leave display as null
      }
    }

    // Parse license from string if available
    ArtworkDisplayLicense? license;
    if (item.license != null && item.license!.isNotEmpty) {
      try {
        license = ArtworkDisplayLicense.fromString(item.license!);
      } catch (e) {
        // If parsing fails, default to open
        license = ArtworkDisplayLicense.open;
      }
    }

    return DP1Item(
      id: item.id,
      title: item.title,
      source: item.sourceUri ?? item.thumbnailUri,
      duration: item.durationSec ?? 0,
      license: license,
      ref: item.refUri,
      display: display,
      repro: repro,
      provenance: provenance,
    );
  }
}
