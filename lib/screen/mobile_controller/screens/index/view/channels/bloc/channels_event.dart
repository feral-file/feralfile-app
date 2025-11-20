part of 'channels_bloc.dart';

/// Enum for channel types
enum ChannelType {
  curated,
  me,
  global;

  String get name => switch (this) {
        ChannelType.curated => 'Curated',
        ChannelType.me => 'Me',
        ChannelType.global => 'Global',
      };

  String get icon => switch (this) {
        ChannelType.curated => 'assets/images/D.svg',
        ChannelType.me => 'assets/images/icon_account.svg',
        ChannelType.global => 'assets/images/icon_global.svg',
      };

  String get description => switch (this) {
        ChannelType.curated =>
          'Curated channels are curated by the team to help you discover new content. '
          'View all curated channels by clicking the button below.',
        ChannelType.me =>
          'Me channels are channels created by the user to help you discover new content. '
          'View all me channels by clicking the button below.',
        ChannelType.global =>
          'Global channels are channels created by the team to help you discover new content. '
          'View all global channels by clicking the button below.',
      };
}

abstract class ChannelsEvent {
  const ChannelsEvent();
}

class LoadChannelsEvent extends ChannelsEvent {
  const LoadChannelsEvent();
}

class LoadMoreChannelsEvent extends ChannelsEvent {
  const LoadMoreChannelsEvent();
}

class RefreshChannelsEvent extends ChannelsEvent {
  const RefreshChannelsEvent();
}
