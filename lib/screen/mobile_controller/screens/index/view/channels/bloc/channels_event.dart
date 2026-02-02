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
          'A small set of Channels selected by Feral File and invited collaborators. '
              'These are early recommendations designed to give you strong entry points into digital art.',
        ChannelType.me => 'Public Channels gathered from across the ecosystem. '
            'They’re not ranked or popularity-based—they simply give you a wide view of what’s out there, organized by source.',
        ChannelType.global =>
          'Public Channels gathered from across the ecosystem. '
              'They’re not ranked or popularity-based—they simply give you a wide view of what’s out there, organized by source.',
      };
}

abstract class ChannelsEvent {
  const ChannelsEvent();
}

class LoadChannelsEvent extends ChannelsEvent {
  const LoadChannelsEvent({this.size});

  final int? size;
}

class LoadMoreChannelsEvent extends ChannelsEvent {
  const LoadMoreChannelsEvent();
}

class RefreshChannelsEvent extends ChannelsEvent {
  const RefreshChannelsEvent({this.size});

  final int? size;
}
