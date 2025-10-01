import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/gateway/mobile_controller_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/utils/json_stream.dart';
import 'package:autonomy_flutter/util/eth_utils.dart';
import 'package:autonomy_flutter/util/file_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/xtz_utils.dart';

class MobileControllerService {
  MobileControllerService(this.api);

  final MobileControllerAPI api;

  /// Gọi API và trả về intent, dp1_call
  Future<(DP1Call dp1Call, AiIntent intent, String response)>
      getDP1CallFromText({
    required String command,
    required List<String> deviceNames,
  }) async {
    final body = {
      'command': command,
      'device_names': deviceNames,
    };
    final result = await api.getDP1CallFromText(body);
    final dp1call =
        DP1Call.fromJson(Map<String, dynamic>.from(result['dp1_call'] as Map));
    final intent =
        AiIntent.fromJson(Map<String, dynamic>.from(result['intent'] as Map));
    final response = result['response'] as String;
    return (dp1call, intent, response);
  }

  //getDP1CallFromVoice
  Future<Stream<Map<String, dynamic>>> getDP1CallFromVoice({
    required File file,
    required List<String> deviceNames,
  }) async {
    final bytes = await file.toBytes();
    final base64String = base64Encode(bytes);
    final body = {
      'device_names': deviceNames,
      'audio': base64String,
    };
    try {
      final result = await api.getDP1CallFromVoiceStream(
        body,
      );
      final listIntStream = result.cast<List<int>>();
      return JsonStream(listIntStream).stream;
    } catch (e) {
      log.info('getDP1CallFromVoice error: $e');
      rethrow;
    }
  }

  Future<Stream<Map<String, dynamic>>> getDP1CallFromTextStream({
    required String command,
    required List<String> deviceNames,
  }) async {
    final body = {
      'device_names': deviceNames,
      'command': command,
    };
    try {
      // check if command is ethereum address or ens or tezos address or tns
      if (command.isEthereumAddressFormat() ||
          command.isENSFormat() ||
          command.isTezosAddressFormat() ||
          command.isTNSFormat()) {
        // for this case, we shouldn't call the api,instead, we should validate the address or resolve the dns, then build and return the stream, simulate the api
        return _simulateAddressOrDomainStream(command);
      }

      final result = await api.getDP1CallFromTextStream(
        body,
      );
      final listIntStream = result.cast<List<int>>();
      return JsonStream(listIntStream).stream;
    } catch (e) {
      log.info('getDP1CallFromVoice error: $e');
      rethrow;
    }
  }
}

extension on MobileControllerService {
  Future<Stream<Map<String, dynamic>>> _simulateAddressOrDomainStream(
    String command,
  ) async {
    final events = <Map<String, dynamic>>[];

    Map<String, dynamic> event(
      NLParserDataType type,
      String content, [
      Map<String, dynamic> data = const {},
    ]) =>
        {
          'type': type.value,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
          'data': data,
        };

    events
      ..add(
        event(
          NLParserDataType.intent,
          'Parsed intent: ${AiAction.addAddress.value}',
          {
            'action': AiAction.addAddress.value,
            'entities': [
              {
                'type': AiEntityType.address.value,
                'name': command,
                'probability': 1.0,
              },
            ],
          },
        ),
      )
      ..add(
        event(
          NLParserDataType.complete,
          'Request completed successfully',
        ),
      );
    return Stream.fromIterable(events);
  }
}

enum NLParserAction {
  getCurrentPlaylist,
  Unknown;

  String get value {
    switch (this) {
      case NLParserAction.getCurrentPlaylist:
        return 'get_current_playlist';
      case NLParserAction.Unknown:
        return 'Unknown';
      default:
        return 'Unknown';
    }
  }

  // Factory method to create an instance from a string
  factory NLParserAction.fromString(String value) {
    switch (value) {
      case 'get_current_playlist':
        return NLParserAction.getCurrentPlaylist;
      default:
        return NLParserAction.Unknown;
    }
  }
}

enum NLParserDataType {
  transcription,
  thinking,
  intent,
  complete,
  summary,
  dp1Call,
  response,
  unknown,
  error;

  String get value {
    switch (this) {
      case NLParserDataType.transcription:
        return 'transcription';
      case NLParserDataType.thinking:
        return 'thinking';
      case NLParserDataType.intent:
        return 'intent';
      case NLParserDataType.complete:
        return 'complete';
      case NLParserDataType.summary:
        return 'summary';
      case NLParserDataType.dp1Call:
        return 'dp1_call';
      case NLParserDataType.response:
        return 'response';
      case NLParserDataType.error:
        return 'error';
      default:
        return 'Unknown';
    }
  }

  // Factory method to create an instance from a string
  factory NLParserDataType.fromString(String value) {
    switch (value) {
      case 'transcription':
        return NLParserDataType.transcription;
      case 'thinking':
        return NLParserDataType.thinking;
      case 'intent':
        return NLParserDataType.intent;
      case 'complete':
        return NLParserDataType.complete;
      case 'summary':
        return NLParserDataType.summary;
      case 'dp1_call':
        return NLParserDataType.dp1Call;
      case 'error':
        return NLParserDataType.error;
      case 'response':
        return NLParserDataType.response;
      default:
        throw NLParserDataType.unknown;
    }
  }
}

class NLParserData {
  // fromJson method to create an object from a JSON map
  factory NLParserData.fromJson(Map<String, dynamic> json) {
    return NLParserData(
      type: NLParserDataType.fromString(json['type'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      data: json['data'] == null
          ? {}
          : Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  NLParserData({
    required this.type,
    required this.content,
    DateTime? timestamp,
    required this.data,
  }) : timestamp = timestamp ?? DateTime.now();
  final NLParserDataType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  // toJson method to convert the object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
    };
  }
}
