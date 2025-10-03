import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';

class PlaylistReference {
  PlaylistReference({required this.playlist, required this.url});
  final DP1Call playlist;
  final String url;
}

class ChannelReference {
  ChannelReference({required this.channel, required this.url});
  final Channel channel;
  final String url;
}
