part of 'channel_preview_bloc.dart';

abstract class ChannelPreviewEvent {
  const ChannelPreviewEvent();
}

class GetChannelPreviewEvent extends ChannelPreviewEvent {
  const GetChannelPreviewEvent();
}

class LoadMoreChannelPreviewItemsEvent extends ChannelPreviewEvent {
  const LoadMoreChannelPreviewItemsEvent();
}


