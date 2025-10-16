import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:equatable/equatable.dart';

abstract class AddLocalFeedServerEvent extends AuEvent {
  const AddLocalFeedServerEvent();
}

class LoadPlaylistsEvent extends AddLocalFeedServerEvent
    with EventWithResultMixin {
  LoadPlaylistsEvent(
    this.url, {
    FutureOr<void> Function()? onComplete,
    FutureOr<void> Function(Object error)? onError,
  }) {
    super.init(onComplete: onComplete, onError: onError);
  }

  final String url;
}

class LoadMorePlaylistsEvent extends AddLocalFeedServerEvent {
  const LoadMorePlaylistsEvent();
}

class AddServerEvent extends AddLocalFeedServerEvent with EventWithResultMixin {
  AddServerEvent({
    FutureOr<void> Function()? onComplete,
    FutureOr<void> Function(Object error)? onError,
  }) {
    super.init(onComplete: onComplete, onError: onError);
  }
}

class ClearErrorEvent extends AddLocalFeedServerEvent {
  const ClearErrorEvent();
}

class ResetEvent extends AddLocalFeedServerEvent {
  const ResetEvent();
}
