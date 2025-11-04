import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';

/// Change journal entry
class Change {
  Change({
    required this.id,
    required this.tokenCid,
    required this.subjectType,
    required this.subjectId,
    required this.changedAt,
    this.meta,
    this.subject,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String tokenCid;
  final String subjectType;
  final String subjectId;
  final DateTime changedAt;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? subject;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Change.fromJson(Map<String, dynamic> json) => Change(
        id: int.tryParse(json['id'].toString()) ?? 0,
        tokenCid: json['token_cid'] as String,
        subjectType: json['subject_type'] as String,
        subjectId: json['subject_id'] as String,
        changedAt:
            DateTime.tryParse(json['changed_at'] as String) ?? DateTime.now(),
        meta: json['meta'] != null
            ? Map<String, dynamic>.from(json['meta'] as Map)
            : null,
        subject: json['subject'] != null
            ? Map<String, dynamic>.from(json['subject'] as Map)
            : null,
        createdAt:
            DateTime.tryParse(json['created_at'] as String) ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'token_cid': tokenCid,
        'subject_type': subjectType,
        'subject_id': subjectId,
        'changed_at': changedAt.toIso8601String(),
        'meta': meta,
        'subject': subject,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Paginated changes list
class ChangeList {
  ChangeList({
    required this.items,
    this.offset,
    required this.total,
  });

  final List<Change> items;
  final int? offset;
  final int total;

  factory ChangeList.fromJson(Map<String, dynamic> json) => ChangeList(
        items: json['items'] != null
            ? List<Change>.from(
                (json['items'] as List<dynamic>).map(
                  (x) => Change.fromJson(x as Map<String, dynamic>),
                ),
              )
            : [],
        offset: json['offset'] != null
            ? int.tryParse(json['offset'].toString())
            : null,
        total: int.tryParse(json['total'].toString()) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((x) => x.toJson()).toList(),
        'offset': offset,
        'total': total,
      };
}

/// Request model for querying changes
class QueryChangesRequest {
  QueryChangesRequest({
    this.tokenCids = const [],
    this.addresses = const [],
    this.since,
    this.limit = 20,
    this.offset = 0,
    this.order = Order.asc,
    this.expand = const [],
  });

  final List<String> tokenCids;
  final List<String> addresses;
  final String? since;
  final int limit;
  final int offset;
  final Order order;
  final List<String> expand;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'order': order.toJson(),
    };

    if (tokenCids.isNotEmpty) {
      json['token_cid'] = tokenCids;
    }

    if (addresses.isNotEmpty) {
      json['address'] = addresses;
    }

    if (since != null && since!.isNotEmpty) {
      json['since'] = since;
    }

    if (expand.isNotEmpty) {
      json['expand'] = expand;
    }

    return json;
  }
}
