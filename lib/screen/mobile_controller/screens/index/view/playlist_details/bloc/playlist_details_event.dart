import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';

abstract class PlaylistDetailsEvent {}

class SetPlaylistEvent extends PlaylistDetailsEvent {
  final DP1Call playlist;
  SetPlaylistEvent({required this.playlist});
}

class GetPlaylistDetailsEvent extends PlaylistDetailsEvent {
  final int size;
  GetPlaylistDetailsEvent({int? size}) : size = size ?? 10;
}

class LoadMorePlaylistDetailsEvent extends PlaylistDetailsEvent {}
