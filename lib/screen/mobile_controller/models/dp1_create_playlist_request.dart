import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

class DP1CreatePlaylistRequest {
  DP1CreatePlaylistRequest({
    required this.dpVersion,
    required this.title,
    this.defaults,
    required this.items,
    this.dynamicQueries,
  });

  final String dpVersion; // e.g., "1.0.0"
  final String title;
  final Map<String, dynamic>? defaults; // e.g., {"display": {...}}

  final List<DP1Item> items;
  final List<DynamicQuery>? dynamicQueries;

  Map<String, dynamic> toJson() => {
        'dpVersion': dpVersion,
        'title': title,
        'defaults': defaults,
        'items': items.map((e) => e.toJson()).toList(),
        'dynamicQueries': dynamicQueries?.map((e) => e.toJson()).toList(),
      };

  factory DP1CreatePlaylistRequest.fromDP1Call(DP1Call dp1Call) =>
      DP1CreatePlaylistRequest(
        dpVersion: dp1Call.dpVersion,
        title: dp1Call.title,
        defaults: dp1Call.defaults,
        items: dp1Call.items,
        dynamicQueries: dp1Call.dynamicQueries,
      );
}
