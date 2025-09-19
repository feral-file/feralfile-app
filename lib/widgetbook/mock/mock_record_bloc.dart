import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_mobile_controller.dart';

class MockRecordBloc extends RecordBloc {
  MockRecordBloc(
    MobileControllerService service,
    AudioService audioService,
    ConfigurationService configurationService,
  ) : super(service, audioService, configurationService);

  @override
  void add(RecordEvent event) {
    if (event is SubmitTextEvent) {
      // Use shared mock data for text submission
      final mockDp1Call = MockMobileControllerData.mockRecordPlaylist;

      final mockIntent = AiIntent(
        action: AiAction.now,
        deviceName: 'Mock Record Device',
      );

      emit(RecordSuccessState(
        lastDP1Call: mockDp1Call,
        lastIntent: mockIntent,
        response: 'Mock response for: ${event.text}',
        transcription: event.text,
      ));
    } else if (event is StartRecordingEvent) {
      // Mock recording state
      emit(RecordRecordingState());
    } else if (event is StopRecordingEvent) {
      // Use shared mock data for voice recording
      final mockDp1Call = MockMobileControllerData.mockVoicePlaylist;

      final mockIntent = AiIntent(
        action: AiAction.now,
        deviceName: 'Mock Voice Device',
      );

      emit(RecordSuccessState(
        lastDP1Call: mockDp1Call,
        lastIntent: mockIntent,
        response: 'Mock voice response',
        transcription: 'Mock voice transcription',
      ));
    } else if (event is ResetPlaylistEvent) {
      // Mock reset state
      emit(RecordInitialState());
    } else {
      super.add(event);
    }
  }
}
