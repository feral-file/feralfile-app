// Mock data factory for DP1Item objects
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';

class MockDP1ItemData {
  // Create basic DP1Item object
  static DP1Item create({
    String id = 'item_1',
    String? title,
    String? source,
    int duration = 30,
    String? ref,
    String? license,
    DP1Provenance? provenance,
  }) {
    return DP1Item(
      id: id,
      title: title,
      source: source,
      duration: duration,
      ref: ref,
      license:
          license != null ? ArtworkDisplayLicense.fromString(license) : null,
      provenance: provenance,
    );
  }

  // Create list of items
  static List<DP1Item> createList({
    int count = 20,
    String idPrefix = 'item',
  }) {
    return List.generate(count, (index) {
      final id = '${idPrefix}_${index + 1}';
      return create(
        id: id,
        title: 'Item ${index + 1}',
        source: 'https://example.com/item${index + 1}',
        duration: 30 + (index * 15), // 30, 45, 60 seconds
      );
    });
  }

  // Create single item
  static DP1Item createSingle({
    String id = 'single_item',
  }) {
    return create(
      id: id,
      title: 'Single Item',
      source: 'https://example.com/single',
      duration: 30,
    );
  }

  // Create item with provenance
  static DP1Item createWithProvenance({
    String id = 'item_with_provenance',
    String title = 'Item with Provenance',
    String? source,
    int duration = 120,
    DP1ProvenanceType provenanceType = DP1ProvenanceType.onChain,
  }) {
    final provenance = DP1Provenance(
      type: provenanceType,
      contract: DP1Contract(
        chain: DP1ProvenanceChain.evm,
        address: '0x1234567890123456789012345678901234567890',
        tokenId: '1',
      ),
    );

    return create(
      id: id,
      title: title,
      source: source,
      duration: duration,
      provenance: provenance,
    );
  }

  // Create item with license
  static DP1Item createWithLicense({
    String id = 'item_with_license',
    String title = 'Item with License',
    String license = 'open',
  }) {
    return create(
      id: id,
      title: title,
      license: license,
      duration: 90,
    );
  }

  // Create minimal item
  static DP1Item createMinimal({
    String id = 'minimal_item',
  }) {
    return create(
      id: id,
      duration: 1,
    );
  }

  // Create item with long duration
  static DP1Item createWithLongDuration({
    String id = 'long_duration_item',
    String title = 'Long Duration Item',
    int duration = 3600, // 1 hour
  }) {
    return create(
      id: id,
      title: title,
      duration: duration,
      source: 'https://example.com/long-video',
    );
  }

  // Create item with reference
  static DP1Item createWithRef({
    String id = 'item_with_ref',
    String title = 'Item with Reference',
    String ref = 'ref-12345',
  }) {
    return create(
      id: id,
      title: title,
      ref: ref,
      duration: 60,
    );
  }

  // Create item with source URL
  static DP1Item createWithSource({
    String id = 'item_with_source',
    String title = 'Item with Source',
    String source = 'https://example.com/artwork',
  }) {
    return create(
      id: id,
      title: title,
      source: source,
      duration: 45,
    );
  }

  // Create item with Tezos provenance
  static DP1Item createWithTezosProvenance({
    String id = 'tezos_item',
    String title = 'Tezos Item',
  }) {
    final provenance = DP1Provenance(
      type: DP1ProvenanceType.onChain,
      contract: DP1Contract(
        chain: DP1ProvenanceChain.tezos,
        address: 'KT1ABC123DEF456GHI789JKL012MNO345PQR678',
        tokenId: '42',
      ),
    );

    return create(
      id: id,
      title: title,
      duration: 120,
      provenance: provenance,
    );
  }

  // Create item with series registry provenance
  static DP1Item createWithSeriesProvenance({
    String id = 'series_item',
    String title = 'Series Item',
  }) {
    final provenance = DP1Provenance(
      type: DP1ProvenanceType.seriesRegistry,
      contract: DP1Contract(
        chain: DP1ProvenanceChain.evm,
        seriesId: 'series-123',
      ),
    );

    return create(
      id: id,
      title: title,
      duration: 90,
      provenance: provenance,
    );
  }

  // Create item with off-chain URI provenance
  static DP1Item createWithOffChainProvenance({
    String id = 'offchain_item',
    String title = 'Off-chain Item',
  }) {
    final provenance = DP1Provenance(
      type: DP1ProvenanceType.offChainURI,
      contract: DP1Contract(
        chain: DP1ProvenanceChain.evm,
        address: '0x0000000000000000000000000000000000000000',
        tokenId: '0',
        uri: 'https://example.com/metadata.json',
      ),
    );

    return create(
      id: id,
      title: title,
      duration: 75,
      provenance: provenance,
    );
  }

  // Create item with restricted license
  static DP1Item createWithRestrictedLicense({
    String id = 'restricted_item',
    String title = 'Restricted Item',
  }) {
    return createWithLicense(
      id: id,
      title: title,
      license: 'restricted',
    );
  }

  // Create empty item list
  static List<DP1Item> createEmpty() => [];

  // Create items with different durations
  static List<DP1Item> createWithDifferentDurations({
    List<int> durations = const [30, 60, 120, 300],
  }) {
    return durations.map((duration) {
      return create(
        id: 'item_${duration}s',
        title: 'Item ${duration}s',
        duration: duration,
        source: 'https://example.com/item-${duration}s',
      );
    }).toList();
  }

  // Create items with different licenses
  static List<DP1Item> createWithDifferentLicenses({
    List<String> licenses = const ['open', 'restricted'],
  }) {
    return licenses.map((license) {
      return createWithLicense(
        id: '${license}_item',
        title: '${license.toUpperCase()} Item',
        license: license,
      );
    }).toList();
  }

  // Create items with different provenance types
  static List<DP1Item> createWithDifferentProvenance() {
    return [
      createWithProvenance(
        id: 'onchain_item',
        title: 'On-chain Item',
        provenanceType: DP1ProvenanceType.onChain,
      ),
      createWithSeriesProvenance(),
      createWithOffChainProvenance(),
    ];
  }

  // Create item with all properties
  static DP1Item createComplete({
    String id = 'complete_item',
    String title = 'Complete Item',
    String source = 'https://example.com/complete',
    int duration = 180,
    String ref = 'ref-complete',
    String license = 'open',
  }) {
    final provenance = DP1Provenance(
      type: DP1ProvenanceType.onChain,
      contract: DP1Contract(
        chain: DP1ProvenanceChain.evm,
        address: '0xABCDEF1234567890ABCDEF1234567890ABCDEF12',
        tokenId: '999',
        standard: DP1ProvenanceStandard.erc721,
        uri: 'https://example.com/metadata/999',
        metaHash: 'abc123def456',
      ),
    );

    return create(
      id: id,
      title: title,
      source: source,
      duration: duration,
      ref: ref,
      license: license,
      provenance: provenance,
    );
  }
}
