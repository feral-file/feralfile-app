import 'package:autonomy_flutter/nft_collection/utils/constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

class DP1Call {
  DP1Call({
    required this.dpVersion,
    required this.id,
    required this.slug,
    required this.title,
    required this.created,
    this.defaults,
    required this.items,
    required this.signature,
    this.dynamicQueries = const [],
  }) {
    // if (items.isEmpty && dynamicQueries.isEmpty) {
    //   throw Exception('There is no artwork in the playlist');
    // }
  } // asset items ií not empty or dynamic queries is not empty

  // from JSON
  factory DP1Call.fromJson(Map<String, dynamic> json) {
    return DP1Call(
      dpVersion: json['dpVersion'] as String,
      id: json['id'] as String,
      slug: json['slug'] as String? ?? 'slug',
      title: json['title'] as String? ?? '',
      created: DateTime.parse(json['created'] as String),
      defaults: json['defaults'] as Map<String, dynamic>?,
      items: (json['items'] as List<dynamic>)
          .map((e) => DP1Item.fromJson(e as Map<String, dynamic>))
          .toList(),
      signature: json['signature'] as String,
      dynamicQueries: (json['dynamicQueries'] == null)
          ? []
          : (List<dynamic>.from(json['dynamicQueries'] as List))
              .map((e) =>
                  DynamicQuery.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }

  final String dpVersion; // e.g., "1.0.0"
  final String id; // e.g., "refik-anadol-20250626T063826"
  final String slug; // e.g., "summer‑mix‑01"
  final String title;
  final DateTime created; // e.g., "2025-06-26T06:38:26.396Z"
  final Map<String, dynamic>? defaults; // e.g., {"display": {...}}
  final List<DP1Item> items; // list of DP1PlaylistItem
  final String signature;
  final List<DynamicQuery> dynamicQueries;

  Map<String, dynamic> toJson() {
    return {
      'dpVersion': dpVersion,
      'id': id,
      'slug': slug,
      'title': title,
      'created': created.toIso8601String(),
      'defaults': defaults,
      'items': items.map((e) => e.toJson()).toList(),
      'signature': signature,
    };
  }

  DynamicQuery? get firstDynamicQuery =>
      dynamicQueries.isNotEmpty ? dynamicQueries.first : null;

  // copyWith method
  DP1Call copyWith({
    String? dpVersion,
    String? id,
    String? slug,
    String? title,
    DateTime? created,
    Map<String, dynamic>? defaults,
    List<DP1Item>? items,
    String? signature,
    List<DynamicQuery>? dynamicQueries,
  }) {
    return DP1Call(
      dpVersion: dpVersion ?? this.dpVersion,
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      created: created ?? this.created,
      defaults: defaults ?? this.defaults,
      items: items ?? this.items,
      signature: signature ?? this.signature,
      dynamicQueries: dynamicQueries ?? this.dynamicQueries,
    );
  }

  // == operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DP1Call && other.dpVersion == dpVersion && other.id == id;
  }

  bool isItemsEqual(Object other) {
    if (identical(this, other)) return true;
    return other is DP1Call && other.items == items;
  }
}

/// Extension for removing duplicate playlists based on unique identifiers
extension DP1CallListExtension on List<DP1Call> {
  /// Remove duplicate playlists based on unique identifiers
  List<DP1Call> removeDuplicates() {
    final seenIds = <String>{};
    final uniquePlaylists = <DP1Call>[];

    for (final playlist in this) {
      // DP1Call has id field as String (required)
      final uniqueId = playlist.id;

      if (!seenIds.contains(uniqueId)) {
        seenIds.add(uniqueId);
        uniquePlaylists.add(playlist);
      }
    }

    return uniquePlaylists;
  }
}

class DynamicQuery {
  DynamicQuery({
    required this.endpoint,
    required this.params,
  });

  final String endpoint;
  final DynamicQueryParams params;

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'params': params.toJson(),
    };
  }

  factory DynamicQuery.fromJson(Map<String, dynamic> json) {
    return DynamicQuery(
      endpoint: json['endpoint'] as String,
      params:
          DynamicQueryParams.fromJson(json['params'] as Map<String, dynamic>),
    );
  }

  // copyWith method
  DynamicQuery copyWith({
    String? endpoint,
    DynamicQueryParams? params,
  }) {
    return DynamicQuery(
        endpoint: endpoint ?? this.endpoint, params: params ?? this.params);
  }

  DynamicQuery insertAddresses(List<String> addresses) {
    return copyWith(params: params.insertAddresses(addresses));
  }

  DynamicQuery removeAddresses(List<String> addresses) {
    return copyWith(params: params.removeAddresses(addresses));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DynamicQuery) return false;
    return endpoint == other.endpoint && params == other.params;
  }

  @override
  int get hashCode => Object.hash(endpoint, params);
}

class DynamicQueryParams {
  DynamicQueryParams({
    required this.owners,
    this.sortBy = IndexerAssetTokenSortBy.lastActivityTime,
  });

  final List<String> owners;
  IndexerAssetTokenSortBy sortBy;

  Map<String, dynamic> toJson() {
    return {
      'owners': owners.join(','),
      'sortBy': sortBy.toJson(),
    };
  }

  factory DynamicQueryParams.fromJson(Map<String, dynamic> json) {
    final ownersData = json['owners'];
    List<String> owners;
    if (ownersData is String) {
      owners = ownersData.split(',').where((s) => s.isNotEmpty).toList();
    } else if (ownersData is List) {
      owners = ownersData.cast<String>();
    } else {
      owners = [];
    }
    return DynamicQueryParams(owners: owners);
  }

  // copyWith method
  DynamicQueryParams copyWith({
    List<String>? owners,
  }) {
    return DynamicQueryParams(owners: owners ?? this.owners);
  }

  DynamicQueryParams insertAddresses(List<String> addresses) {
    return copyWith(owners: [...owners, ...addresses].toSet().toList());
  }

  DynamicQueryParams removeAddresses(List<String> addresses) {
    return copyWith(
        owners: owners.where((e) => !addresses.contains(e)).toList());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DynamicQueryParams) return false;
    // Compare owners order-insensitively
    final a = List<String>.from(owners)..sort();
    final b = List<String>.from(other.owners)..sort();
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final sorted = List<String>.from(owners)..sort();
    return Object.hashAll(sorted);
  }
}
