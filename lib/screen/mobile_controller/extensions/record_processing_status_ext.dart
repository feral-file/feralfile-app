import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';

extension RecordProcessingStatusEx on RecordProcessingStatus {
  String get message {
    switch (this) {
      case RecordProcessingStatus.transcribing:
        return MessageConstants.recordTranscriptionText;
      case RecordProcessingStatus.transcribed:
        return MessageConstants.recordProcessingText;
      case RecordProcessingStatus.thinking:
        return '';
      case RecordProcessingStatus.intentReceived:
      case RecordProcessingStatus.dp1CallReceived:
      case RecordProcessingStatus.responseReceived:
      case RecordProcessingStatus.completed:
        return MessageConstants.recordIntentReceivedText;
    }
  }
}
