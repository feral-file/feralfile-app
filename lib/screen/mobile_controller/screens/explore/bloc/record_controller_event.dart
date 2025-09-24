part of 'record_controller_bloc.dart';

abstract class RecordEvent {}

class StartRecordingEvent extends RecordEvent {}

class StopRecordingEvent extends RecordEvent {}

class PermissionGrantedEvent extends RecordEvent {}

class SubmitTextEvent extends RecordEvent {
  SubmitTextEvent(this.text);

  final String text;
}

class ResetPlaylistEvent extends RecordEvent {}

class AddAddressEvent extends RecordEvent {
  AddAddressEvent(this.text);

  final String text;
}
