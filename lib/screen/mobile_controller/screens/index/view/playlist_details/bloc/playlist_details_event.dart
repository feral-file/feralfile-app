import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';

abstract class PlaylistDetailsEvent {}

class SetPlaylistDetailsEvent extends PlaylistDetailsEvent {
  final DP1Call playlist;
  SetPlaylistDetailsEvent({required this.playlist});
}

class GetPlaylistDetailsEvent extends PlaylistDetailsEvent {}

class LoadMorePlaylistDetailsEvent extends PlaylistDetailsEvent {}
