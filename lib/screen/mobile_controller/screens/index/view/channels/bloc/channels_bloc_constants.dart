import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';

/// Constants for managing multiple ChannelsBloc instances
enum ChannelsBlocInstance {
  curated,
  me,
  global;

  String get instanceName {
    switch (this) {
      case ChannelsBlocInstance.curated:
        return 'curated_channels_bloc';
      case ChannelsBlocInstance.me:
        return 'me_channels_bloc';
      case ChannelsBlocInstance.global:
        return 'global_channels_bloc';
    }
  }

  ChannelType get channelType {
    switch (this) {
      case ChannelsBlocInstance.curated:
        return ChannelType.curated;
      case ChannelsBlocInstance.me:
        return ChannelType.me;
      case ChannelsBlocInstance.global:
        return ChannelType.global;
    }
  }
}


