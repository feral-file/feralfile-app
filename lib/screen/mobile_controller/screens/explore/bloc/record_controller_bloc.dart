// Event
import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/record_processing_status_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:bloc/bloc.dart';

part 'record_controller_event.dart';
part 'record_controller_state.dart';

// Bloc
class RecordBloc extends AuBloc<RecordEvent, RecordState> {
  RecordBloc(this.service, this.audioService, this.configurationService)
      : super(RecordInitialState()) {
    on<PermissionGrantedEvent>(_onPermissionGranted);
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<SubmitTextEvent>(_onSubmitText);

    on<ResetPlaylistEvent>((event, emit) {
      emit(RecordInitialState());
    });
  }

  @override
  void add(RecordEvent event) {
    log.info('[RecordBloc] Adding event: $event');
    super.add(event);
  }

  final MobileControllerService service;
  final AudioService audioService;
  final ConfigurationService configurationService;
  Timer? _statusTimer;

  void _onPermissionGranted(
    PermissionGrantedEvent event,
    Emitter<RecordState> emit,
  ) {
    if (state is RecordErrorState &&
        (state as RecordErrorState).error is AudioPermissionDeniedException) {
      emit(RecordInitialState());
    }
  }

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<RecordState> emit,
  ) async {
    _statusTimer?.cancel();
    emit(RecordInitialState());

    final granted = await audioService.askMicrophonePermission();
    if (!granted) {
      emit(RecordErrorState(error: AudioPermissionDeniedException()));
      return;
    }

    await audioService.startRecording(onSilenceDetected: () {
      add(StopRecordingEvent());
    });
    emit(RecordRecordingState());
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<RecordState> emit,
  ) async {
    if (state is! RecordRecordingState) {
      return;
    }

    final file = await audioService.stopRecording();
    if (file == null) {
      emit(
        RecordErrorState(
          error: AudioRecordNoSpeechException(),
        ),
      ); // Emit RecordNoSpeechState if no audio was recorded
      return;
    }
    emit(
      RecordProcessingState(
        status: RecordProcessingStatus.transcribing,
      ),
    );

    try {
      final devicesName =
          BluetoothDeviceManager.pairedDevices.map((e) => e.name).toList();
      final stream = await service.getDP1CallFromVoice(
        file: file,
        deviceNames: devicesName,
      );
      await _processParserStream(stream, emit);
    } catch (e) {
      emit(
        RecordErrorState(
          error: AudioException('Failed to process audio: $e'),
        ),
      );
    }
  }

  Future<void> _onSubmitText(
    SubmitTextEvent event,
    Emitter<RecordState> emit,
  ) async {
    final text = event.text;
    await configurationService.addRecordedMessage(text);
    emit(
      RecordProcessingState(
        status: RecordProcessingStatus.transcribed,
        transcription: text,
      ),
    );

    try {
      final devicesNames =
          BluetoothDeviceManager.pairedDevices.map((e) => e.name).toList();

      final stream = await service.getDP1CallFromTextStream(
        command: text,
        deviceNames: devicesNames,
      );
      await _processParserStream(stream, emit);
    } catch (e) {
      emit(
        RecordErrorState(
          error: AudioException('Failed to process text: $e'),
        ),
      );
    }
  }

  Future<void> _processParserStream(
    Stream<Map<String, dynamic>> stream,
    Emitter<RecordState> emit,
  ) async {
    await for (final json in stream) {
      try {
        if (state is RecordErrorState) {
          log.info(
              '[RecordBloc] Skipping processing due to error state: $state');
          break;
        }
        final nlParserData =
            NLParserData.fromJson(Map<String, dynamic>.from(json));
        await _handleNLParserData(nlParserData, emit);
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e, s) {
        log.info('[RecordBloc] Error processing data: $e');
        emit(
          RecordErrorState(
            error: AudioException('Error processing data: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleNLParserData(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    switch (nlParserData.type) {
      case NLParserDataType.transcription:
        await _handleTranscription(nlParserData, emit);
      case NLParserDataType.thinking:
        await _handleThinking(nlParserData, emit);
      case NLParserDataType.intent:
        await _handleIntent(nlParserData, emit);
      case NLParserDataType.dp1Call:
        await _handleDP1Call(nlParserData, emit);
      case NLParserDataType.response:
        await _handleResponse(nlParserData, emit);
      case NLParserDataType.complete:
        await _handleComplete(nlParserData, emit);
      case NLParserDataType.error:
        await _handleError(nlParserData, emit);
      default:
        log.warning('Unknown NLParserDataType: [${nlParserData.type}');
    }
  }

  Future<void> _handleTranscription(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    final transcribe = nlParserData.data['corrected_text'] as String;
    await configurationService.addRecordedMessage(transcribe);
    if (state is RecordProcessingState) {
      emit(
        (state as RecordProcessingState).copyWith(
          transcription: transcribe,
          status: RecordProcessingStatus.transcribed,
        ),
      );
    } else {
      emit(
        RecordProcessingState(
          status: RecordProcessingStatus.transcribed,
          transcription: transcribe,
        ),
      );
    }
  }

  Future<void> _handleThinking(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    final thinking = nlParserData.content;
    if (state is RecordProcessingState) {
      emit((state as RecordProcessingState).copyWith(
        statusMessage: thinking,
        status: RecordProcessingStatus.thinking,
      ));
    } else
      emit(
        RecordProcessingState(
          status: RecordProcessingStatus.thinking,
          statusMessage: thinking,
        ),
      );
  }

  Future<void> _handleIntent(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    final intent =
        AiIntent.fromJson(Map<String, dynamic>.from(nlParserData.data as Map));
    if (state is RecordProcessingState) {
      emit((state as RecordProcessingState).copyWith(
          lastIntent: intent,
          status: RecordProcessingStatus.intentReceived,
          statusMessage: intent.displayText));
    } else {
      emit(
        RecordProcessingState(
          status: RecordProcessingStatus.intentReceived,
          lastIntent: intent,
        ),
      );
    }
  }

  Future<void> _handleDP1Call(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    final dp1Call =
        DP1Call.fromJson(Map<String, dynamic>.from(nlParserData.data));
    final intent = state.lastIntent;

    if (intent == null) {
      emit(
        RecordErrorState(
          error: AudioException('No intent available for DP1 call'),
        ),
      );
      return;
    }

    if (state is RecordProcessingState) {
      emit((state as RecordProcessingState).copyWith(
          lastDP1Call: dp1Call,
          status: RecordProcessingStatus.dp1CallReceived));
    } else {
      emit(RecordProcessingState(
        status: RecordProcessingStatus.dp1CallReceived,
        lastDP1Call: dp1Call,
      ));
    }
    return;
  }

  Future<void> _handleResponse(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    log.info('Response action received: ${nlParserData.data}');

    final response = nlParserData.content;
    if (state is RecordProcessingState) {
      emit((state as RecordProcessingState).copyWith(
        status: RecordProcessingStatus.responseReceived,
        response: response,
      ));
    } else {
      emit(RecordProcessingState(
          status: RecordProcessingStatus.responseReceived, response: response));
    }

    // if (state is RecordProcessingState) {
    //   final response = nlParserData.content;
    //   final intent = state.lastIntent!;
    //   final dp1call = state.lastDP1Call!;
    //   final transcription = (state as RecordProcessingState).transcription!;
    //   final successState = RecordSuccessState(
    //     lastIntent: intent,
    //     lastDP1Call: dp1call,
    //     response: response,
    //     transcription: transcription,
    //   );
    //   emit(successState);
    // }
  }

  Future<void> _handleComplete(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    log.info('Complete action received');
    if (state is RecordProcessingState) {
      final transcription = (state as RecordProcessingState).transcription!;
      final intent = state.lastIntent!;
      final dp1call = state.lastDP1Call;
      final successState = RecordSuccessState(
        lastIntent: intent,
        lastDP1Call: dp1call,
        response: (state as RecordProcessingState).response ?? '',
        transcription: transcription,
      );
      emit(successState);
    }
  }

  Future<void> _handleError(
    NLParserData nlParserData,
    Emitter<RecordState> emit,
  ) async {
    final error = nlParserData.content;
    log.info('Error action received: $error');
    emit(
      RecordErrorState(
        error: AudioFailedToParseCommandException(),
      ),
    );
  }
}
