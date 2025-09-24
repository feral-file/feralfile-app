part of 'record_controller_bloc.dart';

enum RecordProcessingStatus {
  transcribing,
  transcribed,
  thinking,
  intentReceived,
  dp1CallReceived,
  responseReceived,
  completed,
}

class RecordState {
  RecordState({
    AiIntent? lastIntent,
    this.lastDP1Call,
  }) : _lastIntent = lastIntent;

  final AiIntent? _lastIntent;
  AiIntent? get lastIntent => _lastIntent;
  final DP1Call? lastDP1Call;

  RecordState copyWith({
    AiIntent? lastIntent,
    DP1Call? lastDP1Call,
  }) =>
      RecordState(
        lastIntent: lastIntent ?? this.lastIntent,
        lastDP1Call: lastDP1Call ?? this.lastDP1Call,
      );

  bool get isValid {
    if (lastIntent?.action == AiAction.addAddress) {
      return true;
    }

    // check if the intent has type open_screen or dp1Call has items
    if ((lastIntent?.action == AiAction.openScreen &&
            (lastIntent?.entities?.any((e) =>
                    e.type == AiEntityType.playlist ||
                    e.type == AiEntityType.channel) ??
                false)) ||
        (lastDP1Call?.items.isNotEmpty ?? false)) {
      return true;
    }
    return false;
  }
}

class RecordInitialState extends RecordState {
  RecordInitialState();
}

class RecordRecordingState extends RecordState {
  RecordRecordingState();
}

class RecordProcessingState extends RecordState {
  RecordProcessingState({
    required this.status,
    super.lastIntent,
    super.lastDP1Call,
    this.statusMessage,
    this.transcription,
    this.response,
  });

  final RecordProcessingStatus status;
  final String? statusMessage;
  final String? transcription;
  final String? response;

  @override
  RecordProcessingState copyWith({
    RecordProcessingStatus? status,
    AiIntent? lastIntent,
    DP1Call? lastDP1Call,
    String? statusMessage,
    String? transcription,
    String? response,
  }) =>
      RecordProcessingState(
        status: status ?? this.status,
        statusMessage: statusMessage ?? this.statusMessage,
        transcription: transcription ?? this.transcription,
        lastIntent: lastIntent ?? this.lastIntent,
        lastDP1Call: lastDP1Call ?? this.lastDP1Call,
        response: response ?? this.response,
      );

  String get processingMessage => statusMessage ?? status.message;
}

class RecordErrorState extends RecordState {
  RecordErrorState({required this.error});

  final Exception error;
}

class RecordSuccessState extends RecordState {
  final String response;
  final String transcription;

  final AiIntent _lastIntentNonNull;
  @override
  AiIntent get lastIntent => _lastIntentNonNull;

  RecordSuccessState({
    required AiIntent lastIntent,
    required DP1Call? lastDP1Call,
    required this.response,
    required this.transcription,
  })  : _lastIntentNonNull = lastIntent,
        super(lastIntent: lastIntent, lastDP1Call: lastDP1Call);
}

class VerifyingAddressState extends RecordState {
  VerifyingAddressState({required this.address});

  final String address;
}

class ResolvingDomainState extends RecordState {
  ResolvingDomainState({required this.ens});

  final String ens;
}

class InvalidAddressState extends RecordState {
  InvalidAddressState({required this.error});

  final String error;
}

class AddingAddressState extends RecordState {
  AddingAddressState({required this.address});

  final String address;
}

class AddAddressErrorState extends RecordState {
  AddAddressErrorState({required this.error});
  final String error;
}

class AddAddressSuccessState extends RecordState {}
