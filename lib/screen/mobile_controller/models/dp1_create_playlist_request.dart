import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

class DP1CreatePlaylistRequest {
  DP1CreatePlaylistRequest({
    required this.dpVersion,
    required this.title,
    required this.items,
    this.dynamicQueries,
  });

  final String dpVersion; // e.g., "1.0.0"
  final String title;
  final List<DP1Item> items;
  final List<DynamicQuery>? dynamicQueries;

  Map<String, dynamic> toJson() => {
        'dpVersion': dpVersion,
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
        'dynamicQueries': dynamicQueries?.map((e) => e.toJson()).toList(),
      };
}
