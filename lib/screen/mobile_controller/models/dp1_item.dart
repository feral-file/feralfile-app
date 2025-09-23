import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';

class DP1PlaylistDisplay {
  DP1PlaylistDisplay({
    required this.scaling,
    required this.margin,
    required this.background,
    required this.autoplay,
    required this.loop,
  });

  final String scaling; // e.g., "fill"
  final int margin; // e.g., 0
  final String background; // e.g., "transparent"
  final bool autoplay;
  final bool loop;

  factory DP1PlaylistDisplay.fromJson(Map<String, dynamic> json) =>
      DP1PlaylistDisplay(
        scaling: json['scaling'] as String,
        margin: (json['margin'] as num).toInt(),
        background: json['background'] as String,
        autoplay: json['autoplay'] as bool,
        loop: json['loop'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'scaling': scaling,
        'margin': margin,
        'background': background,
        'autoplay': autoplay,
        'loop': loop,
      };
}

class DP1Item {
  DP1Item({
    required this.duration,
    required this.provenance,
    this.title,
    this.source,
    this.license,
    this.display,
  }); // e.g., "open", "restricted", etc.

// from JSON
  factory DP1Item.fromJson(Map<String, dynamic> json) {
    try {
      return DP1Item(
        title: json['title'] as String?,
        source: json['source'] as String?,
        duration: json['duration'] as int,
        license: json['license'] == null
            ? null
            : ArtworkDisplayLicense.fromString(
                json['license'] as String,
              ),
        display: json['display'] == null
            ? null
            : DP1PlaylistDisplay.fromJson(
                Map<String, dynamic>.from(json['display'] as Map),
              ),
        provenance: DP1Provenance.fromJson(
          Map<String, dynamic>.from(json['provenance'] as Map),
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  final String? title;
  final String? source;
  final int duration; // in seconds
  final ArtworkDisplayLicense? license;
  final DP1PlaylistDisplay? display;
  final DP1Provenance provenance;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'source': source,
      'duration': duration,
      'license': license?.value,
      'display': display?.toJson(),
      'provenance': provenance.toJson(),
    };
  }
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
  String get indexId => provenance.indexId;
}

/// Extension for removing duplicate items based on unique identifiers
extension DP1ItemListExtension on List<DP1Item> {
  /// Remove duplicate items based on unique identifiers
  List<DP1Item> removeDuplicates() {
    final seenIds = <String>{};
    final uniqueItems = <DP1Item>[];

    for (final item in this) {
      // DP1Item doesn't have id field, use provenance contract info as unique identifier
      final contract = item.provenance.contract;
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
