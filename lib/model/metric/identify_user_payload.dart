/*
"properties": {
      "actor_type": "ff1|ff-controller",
      "actor_id": "ff1-00024|ff-controller-0001"
    }
 */
import 'package:autonomy_flutter/model/metric/dp1_playlist_metric.dart';

class IdentifyUserPayload {
  final ActorType actorType;
  final String actorId;

  IdentifyUserPayload({
    required this.actorType,
    required this.actorId,
  });

  Map<String, dynamic> toJson() => {
        'actor_type': actorType.value,
        'actor_id': actorId,
      };
}
