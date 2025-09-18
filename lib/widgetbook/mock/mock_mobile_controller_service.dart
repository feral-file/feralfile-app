import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/gateway/mobile_controller_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/screen/mobile_controller/utils/json_stream.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';

class MockMobileControllerService extends MobileControllerService {
  MockMobileControllerService(MobileControllerAPI api) : super(api);

  @override
  Future<(DP1Call dp1Call, AiIntent intent, String response)>
      getDP1CallFromText({
    required String command,
    required List<String> deviceNames,
  }) async {
    // Mock response
    final mockDp1Call = DP1Call(
      dpVersion: '1.0.0',
      id: 'mock-playlist-id',
      slug: 'mock-playlist',
      title: 'Mock Playlist',
      created: DateTime.now(),
      defaults: {'display': {}},
      items: [
        DP1Item(
          duration: 30,
          provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
              chain: DP1ProvenanceChain.evm,
              standard: DP1ProvenanceStandard.erc721,
              address: '0x1234567890123456789012345678901234567890',
              tokenId: '1',
            ),
          ),
          title: 'Mock Artwork 1',
          source: 'https://example.com/mock-image-1.jpg',
        ),
        DP1Item(
          duration: 45,
          provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
              chain: DP1ProvenanceChain.evm,
              standard: DP1ProvenanceStandard.erc721,
              address: '0x1234567890123456789012345678901234567890',
              tokenId: '2',
            ),
          ),
          title: 'Mock Artwork 2',
          source: 'https://example.com/mock-image-2.jpg',
        ),
      ],
      signature: 'mock-signature',
    );

    final mockIntent = AiIntent(
      action: AiAction.now,
      deviceName: deviceNames.isNotEmpty ? deviceNames.first : 'Mock Device',
    );

    return (mockDp1Call, mockIntent, 'Mock response for: $command');
  }

  @override
  Future<Stream<Map<String, dynamic>>> getDP1CallFromVoice({
    required File file,
    required List<String> deviceNames,
  }) async {
    // Mock stream response
    final mockData = {
      'dp1_call': {
        'id': 'mock-voice-playlist-id',
        'title': 'Mock Voice Playlist',
        'description': 'Mock voice playlist description',
        'items': [
          {
            'id': 'mock-voice-item-1',
            'title': 'Mock Voice Artwork 1',
            'description': 'Mock voice artwork description',
            'image_url': 'https://example.com/mock-voice-image-1.jpg',
            'artist': 'Mock Voice Artist',
            'collection': 'Mock Voice Collection',
          },
        ],
      },
      'intent': {
        'action': 'play',
        'device_name':
            deviceNames.isNotEmpty ? deviceNames.first : 'Mock Voice Device',
        'confidence': 0.85,
      },
      'response': 'Mock voice response',
    };

    return Stream.value(mockData);
  }

  @override
  Future<Stream<Map<String, dynamic>>> getDP1CallFromTextStream({
    required String command,
    required List<String> deviceNames,
  }) async {
    // Mock stream response
    final mockData = {
      'dp1_call': {
        'id': 'mock-stream-playlist-id',
        'title': 'Mock Stream Playlist',
        'description': 'Mock stream playlist description',
        'items': [
          {
            'id': 'mock-stream-item-1',
            'title': 'Mock Stream Artwork 1',
            'description': 'Mock stream artwork description',
            'image_url': 'https://example.com/mock-stream-image-1.jpg',
            'artist': 'Mock Stream Artist',
            'collection': 'Mock Stream Collection',
          },
        ],
      },
      'intent': {
        'action': 'play',
        'device_name':
            deviceNames.isNotEmpty ? deviceNames.first : 'Mock Stream Device',
        'confidence': 0.88,
      },
      'response': 'Mock stream response for: $command',
    };

    return Stream.value(mockData);
  }
}
