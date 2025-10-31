import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

import '../../mock_data/mock_dp1_item_data.dart';

class MockCheckCastingStatusReply {
  /// Minimal OK reply (no items), suitable for status notifications
  static CheckCastingStatusReply basic() {
    final items = MockDP1ItemData.createList(count: 20);
    final index = 10;
    return CheckCastingStatusReply(
      ok: true,
      index: index,
      items: items,
      isPaused: false,
    );
  }

  static CheckCastingStatusReply withItems({
    required List<DP1Item> items,
    required int index,
    bool isPaused = false,
  }) {
    return CheckCastingStatusReply(
      ok: true,
      index: index,
      items: items,
      isPaused: isPaused,
    );
  }
}
