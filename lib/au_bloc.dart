import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

abstract class AuEvent {
  const AuEvent();
}

abstract class AuBloc<Event, State> extends Bloc<Event, State> {
  AuBloc(State initialState) : super(initialState);

  @override
  void add(Event event) {
    if (isClosed) return;
    super.add(event);
  }

  @override
  Future<void> close() {
    return super.close();
  }
}

class EventWithResult {
  EventWithResult({this.onComplete, this.onError});

  final FutureOr<void> Function()? onComplete;
  final FutureOr<void> Function(Object error)? onError;
}

mixin EventWithResultMixin on AuEvent {
  /// Called when event completes successfully
  FutureOr<void> Function()? onComplete;

  /// Called when event throws error
  FutureOr<void> Function(Object error)? onError;

  void init({
    FutureOr<void> Function()? onComplete,
    FutureOr<void> Function(Object error)? onError,
  }) {
    this.onComplete = onComplete;
    this.onError = onError;
  }
}
