import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

class DP1Call {
  DP1Call({
    required this.dpVersion,
    required this.id,
    required this.slug,
    required this.title,
    required this.created,
    required this.defaults,
    required this.items,
    required this.signature,
  }); // e.g., "ed25519:0x884e6b4bab7ab8"

  // from JSON
  factory DP1Call.fromJson(Map<String, dynamic> json) {
    return DP1Call(
      dpVersion: json['dpVersion'] as String,
      id: json['id'] as String,
      slug: json['slug'] as String? ?? 'slug',
      title: json['title'] as String? ?? '',
      created: DateTime.parse(json['created'] as String),
      defaults: json['defaults'] as Map<String, dynamic>,
      items: (json['items'] as List<dynamic>)
          .map((e) => DP1Item.fromJson(e as Map<String, dynamic>))
          .toList(),
      signature: json['signature'] as String,
    );
  }

  final String dpVersion; // e.g., "1.0.0"
  final String id; // e.g., "refik-anadol-20250626T063826"
  final String slug; // e.g., "summer‑mix‑01"
  final String title;
  final DateTime created; // e.g., "2025-06-26T06:38:26.396Z"
  final Map<String, dynamic> defaults; // e.g., {"display": {...}}
  final List<DP1Item> items; // list of DP1PlaylistItem
  final String signature;

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
    );
  }

  DynamicQuery get dynamicQuery => DynamicQuery(
        endpoint: 'https://indexer.feralfile.com/v2/graphql',
        params: DynamicQueryParams(
          owners: ['a3ezwdYVEVrHwszQrYzDTCAZwUD3yKtNsCq9YhEu97bPaGAKy1'],
        ),
      );

  // == operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DP1Call && other.dpVersion == dpVersion && other.id == id;
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
}

class DynamicQueryParams {
  DynamicQueryParams({
    required this.owners,
  });

  final List<String> owners;

  Map<String, dynamic> toJson() {
    return {
      'owners': owners,
    };
  }

  factory DynamicQueryParams.fromJson(Map<String, dynamic> json) {
    return DynamicQueryParams(
      owners: json['owners'] as List<String>,
    );
  }
}
