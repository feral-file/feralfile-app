import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';

class DP1Item {
  DP1Item({
    required this.id,
    required this.duration,
    this.ref,
    this.repro,
    this.title,
    this.provenance,
    this.source,
    this.license,
    this.display,
  }); // e.g., "open", "restricted", etc.

// from JSON
  factory DP1Item.fromJson(Map<String, dynamic> json) {
    try {
      return DP1Item(
        id: json['id'] as String,
        title: json['title'] as String?,
        source: json['source'] as String?,
        duration: json['duration'] as int,
        license: json['license'] == null
            ? null
            : ArtworkDisplayLicense.fromString(
                json['license'] as String,
              ),
        repro: json['repro'] != null
            ? ReproBlock.fromJson(json['repro'] as Map<String, dynamic>)
            : null,
        display: json['display'] == null
            ? null
            : DP1PlaylistDisplay.fromJson(
                Map<String, dynamic>.from(json['display'] as Map),
              ),
        ref: json['ref'] as String?,
        provenance: json['provenance'] == null
            ? null
            : DP1Provenance.fromJson(
                Map<String, dynamic>.from(json['provenance'] as Map),
              ),
      );
    } catch (e) {
      rethrow;
    }
  }

  final String id;
  final String? title;
  final String? source;
  final int duration; // in seconds
  final ArtworkDisplayLicense? license;

  final String? ref;
  final DP1PlaylistDisplay? display;
  final ReproBlock? repro;
  final DP1Provenance? provenance;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'duration': duration,
      'license': license?.value,
      'repro': repro?.toJson(),
      'ref': ref,
      'display': display?.toJson(),
      'provenance': provenance?.toJson(),
    };
  }
}

class DP1PlaylistDisplay {
  DP1PlaylistDisplay({
    this.scaling = 'fit',
    this.margin = 0,
    this.background = '#000000',
    this.autoplay = true,
    this.loop = true,
    this.interaction,
    this.userOverrides = true,
  });

  final String scaling; // "fit", "fill", "stretch"
  final dynamic margin; // number (px) or string (%/vw/vh)
  final String background; // hex color or "transparent"
  final bool autoplay;
  final bool loop;
  final DP1Interaction? interaction;
  final bool userOverrides;

  factory DP1PlaylistDisplay.fromJson(Map<String, dynamic> json) =>
      DP1PlaylistDisplay(
        scaling: json['scaling'] as String? ?? 'fit',
        margin: json['margin'],
        background: json['background'] as String? ?? '#000000',
        autoplay: json['autoplay'] as bool? ?? true,
        loop: json['loop'] as bool? ?? true,
        interaction: json['interaction'] != null
            ? DP1Interaction.fromJson(
                json['interaction'] as Map<String, dynamic>)
            : null,
        userOverrides: json['userOverrides'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'scaling': scaling,
        'margin': margin,
        'background': background,
        'autoplay': autoplay,
        'loop': loop,
        if (interaction != null) 'interaction': interaction!.toJson(),
        'userOverrides': userOverrides,
      };
}

class DP1Interaction {
  DP1Interaction({
    this.keyboard = const [],
    this.mouse,
  });

  final List<String> keyboard; // W3C UI Events code values
  final DP1MouseInteraction? mouse;

  factory DP1Interaction.fromJson(Map<String, dynamic> json) => DP1Interaction(
        keyboard: (json['keyboard'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        mouse: json['mouse'] != null
            ? DP1MouseInteraction.fromJson(
                json['mouse'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'keyboard': keyboard,
        if (mouse != null) 'mouse': mouse!.toJson(),
      };
}

class DP1MouseInteraction {
  DP1MouseInteraction({
    this.click = false,
    this.scroll = false,
    this.drag = false,
    this.hover = false,
  });

  final bool click;
  final bool scroll;
  final bool drag;
  final bool hover;

  factory DP1MouseInteraction.fromJson(Map<String, dynamic> json) =>
      DP1MouseInteraction(
        click: json['click'] as bool? ?? false,
        scroll: json['scroll'] as bool? ?? false,
        drag: json['drag'] as bool? ?? false,
        hover: json['hover'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'click': click,
        'scroll': scroll,
        'drag': drag,
        'hover': hover,
      };
}

class ReproBlock {
  ReproBlock({
    this.engineVersion,
    this.seed,
    this.assetsSHA256,
    this.frameHash,
  });

  final ReproEngineVersion? engineVersion;
  final String? seed;
  final List<String>? assetsSHA256;
  final ReproFrameHash? frameHash;

  factory ReproBlock.fromJson(Map<String, dynamic> json) => ReproBlock(
        engineVersion: json['engineVersion'] != null
            ? ReproEngineVersion.fromJson(
                json['engineVersion'] as Map<String, dynamic>)
            : null,
        seed: json['seed'] as String?,
        assetsSHA256: (json['assetsSHA256'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        frameHash: json['frameHash'] != null
            ? ReproFrameHash.fromJson(json['frameHash'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (engineVersion != null) 'engineVersion': engineVersion!.toJson(),
        if (seed != null) 'seed': seed,
        if (assetsSHA256 != null) 'assetsSHA256': assetsSHA256,
        if (frameHash != null) 'frameHash': frameHash!.toJson(),
      };
}

class ReproEngineVersion {
  ReproEngineVersion({
    this.chromium,
  });

  final String? chromium;

  factory ReproEngineVersion.fromJson(Map<String, dynamic> json) =>
      ReproEngineVersion(
        chromium: json['chromium'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (chromium != null) 'chromium': chromium,
      };
}

class ReproFrameHash {
  ReproFrameHash({
    this.sha256,
    this.phash,
  });

  final String? sha256;
  final String? phash;

  factory ReproFrameHash.fromJson(Map<String, dynamic> json) => ReproFrameHash(
        sha256: json['sha256'] as String?,
        phash: json['phash'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (sha256 != null) 'sha256': sha256,
        if (phash != null) 'phash': phash,
      };
}

enum ArtworkDisplayLicense {
  open,
  restricted;

  String get value {
    switch (this) {
      case ArtworkDisplayLicense.open:
        return 'open';
      case ArtworkDisplayLicense.restricted:
        return 'restricted';
    }
  }

  static ArtworkDisplayLicense fromString(String value) {
    switch (value) {
      case 'open':
        return ArtworkDisplayLicense.open;
      case 'restricted':
        return ArtworkDisplayLicense.restricted;
      default:
        throw ArgumentError('Unknown license type: $value');
    }
  }
}

extension DP1PlaylistItemExt on DP1Item {
  String? get cid => provenance?.cid;

  String get displayKey => (cid ?? '').hashCode.toString();
}

/// Extension for removing duplicate items based on unique identifiers
extension DP1ItemListExtension on List<DP1Item> {
  /// Remove duplicate items based on unique identifiers
  List<DP1Item> removeDuplicates() {
    final seenIds = <String>{};
    final uniqueItems = <DP1Item>[];

    for (final item in this) {
      // DP1Item doesn't have id field, use provenance contract info as unique identifier
      final contract = item.provenance?.contract;
      if (contract == null) {
        continue;
      }
      final uniqueId =
          '${contract.chain.value}-${contract.address ?? ''}-${contract.tokenId ?? ''}-${contract.seriesId ?? ''}';

      if (!seenIds.contains(uniqueId)) {
        seenIds.add(uniqueId);
        uniqueItems.add(item);
      }
    }

    return uniqueItems;
  }
}
