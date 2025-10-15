abstract class CustomFeedServersEvent {}

class LoadCustomFeedServersEvent extends CustomFeedServersEvent {}

class RefreshCustomFeedServersEvent extends CustomFeedServersEvent {}

class RemoveCustomFeedServerEvent extends CustomFeedServersEvent {
  RemoveCustomFeedServerEvent(this.url);
  final String url;
}
