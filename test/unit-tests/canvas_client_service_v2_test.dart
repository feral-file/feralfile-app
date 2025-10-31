import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/gateway/tv_cast_api.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/service/metric_client_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceInfoService extends Mock implements DeviceInfoService {}

class MockTvCastApi extends Mock implements TvCastApi {}

class MockFFBluetoothDevice extends Mock implements FFBluetoothDevice {}

class MockAuthService extends Mock implements AuthService {}

class MockMetricClientService extends Mock implements MetricClientService {}

class MockNavigationService extends Mock implements NavigationService {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockSettingsDataService extends Mock implements SettingsDataService {}

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  group('CanvasClientServiceV2', () {
    late CanvasClientServiceV2 service;
    late MockDeviceInfoService mockDeviceInfoService;
    late MockTvCastApi mockApi;
    late MockFFBluetoothDevice mockDevice;
    late MockAuthService mockAuthService;
    late MockMetricClientService mockMetricClientService;
    late MockNavigationService mockNavigationService;
    late MockConfigurationService mockConfigurationService;
    late MockSettingsDataService mockSettingsDataService;

    setUpAll(() {
      registerFallbackValue(_FakeBuildContext());
    });

    setUp(() {
      mockDeviceInfoService = MockDeviceInfoService();
      mockApi = MockTvCastApi();
      mockDevice = MockFFBluetoothDevice();
      mockAuthService = MockAuthService();
      mockMetricClientService = MockMetricClientService();
      mockNavigationService = MockNavigationService();
      mockConfigurationService = MockConfigurationService();
      mockSettingsDataService = MockSettingsDataService();

      // Injector setup
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      if (injector_module.injector.isRegistered<MetricClientService>()) {
        injector_module.injector.unregister<MetricClientService>();
      }
      if (injector_module.injector.isRegistered<NavigationService>()) {
        injector_module.injector.unregister<NavigationService>();
      }
      if (injector_module.injector.isRegistered<ConfigurationService>()) {
        injector_module.injector.unregister<ConfigurationService>();
      }
      if (injector_module.injector.isRegistered<SettingsDataService>()) {
        injector_module.injector.unregister<SettingsDataService>();
      }
      injector_module.injector.registerSingleton<AuthService>(mockAuthService);
      injector_module.injector.registerSingleton<MetricClientService>(
        mockMetricClientService,
      );
      injector_module.injector
          .registerSingleton<NavigationService>(mockNavigationService);
      injector_module.injector
          .registerSingleton<ConfigurationService>(mockConfigurationService);
      injector_module.injector
          .registerSingleton<SettingsDataService>(mockSettingsDataService);

      // Device info service
      when(() => mockDeviceInfoService.deviceId).thenReturn('client_device_id');
      when(() => mockDeviceInfoService.deviceName).thenReturn('Client Device');

      // Device model fields used by TvCastServiceImpl
      when(() => mockDevice.topicId).thenReturn('topic_id');
      when(() => mockDevice.deviceId).thenReturn('remote_device_id');
      when(() => mockDevice.name).thenReturn('Remote Device');
      when(() => mockDevice.toJson()).thenReturn({
        'deviceId': 'remote_device_id',
        'name': 'Remote Device',
        'topicId': 'topic_id',
      });

      // Auth user id for connect
      when(() => mockAuthService.getUserId()).thenReturn('user_123');

      // Metric merge user no-op
      when(() => mockMetricClientService.mergeUser(any()))
          .thenAnswer((_) async {});

      // Additional dependencies used by TvCastServiceImpl
      when(() => mockNavigationService.context).thenReturn(_FakeBuildContext());
      when(() => mockConfigurationService.setSelectedDeviceId(any()))
          .thenAnswer((_) async {});
      when(() => mockSettingsDataService.backupUserSettings())
          .thenAnswer((_) async {});

      service = CanvasClientServiceV2(mockDeviceInfoService, mockApi);
    });

    tearDown(() {
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      if (injector_module.injector.isRegistered<MetricClientService>()) {
        injector_module.injector.unregister<MetricClientService>();
      }
      if (injector_module.injector.isRegistered<NavigationService>()) {
        injector_module.injector.unregister<NavigationService>();
      }
      if (injector_module.injector.isRegistered<ConfigurationService>()) {
        injector_module.injector.unregister<ConfigurationService>();
      }
      if (injector_module.injector.isRegistered<SettingsDataService>()) {
        injector_module.injector.unregister<SettingsDataService>();
      }
    });

    test('connectToDevice returns true on success and merges user', () async {
      when(() => mockApi.request(
                topicId: any(named: 'topicId'),
                body: any(named: 'body'),
              ))
          // connect
          .thenAnswer((_) async => {
                'message': {'ok': true},
              });

      final ok = await service.connectToDevice(mockDevice);

      expect(ok, isTrue);
      verify(() => mockMetricClientService.mergeUser('remote_device_id'))
          .called(1);
    });

    test('connectToDevice returns false on error', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenThrow(Exception('failed'));

      final ok = await service.connectToDevice(mockDevice);
      expect(ok, isFalse);
    });

    test('castPlaylist (JSON) returns true when connect and cast succeed',
        () async {
      // 1st call: connect, 2nd call: cast
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });

      final dp1 = DP1Call(
        dpVersion: '1.0.0',
        id: 'id',
        slug: 'slug',
        title: 'title',
        created: DateTime.now(),
        items: const [],
        signature: 'sig',
      );
      final ok = await service.castPlaylist(
        mockDevice,
        dp1,
        DP1Intent.displayNow(),
        usingUrl: false,
      );

      expect(ok, isTrue);
    });

    test('castPlaylist returns false when connect fails', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenThrow(Exception('connect error'));

      final dp1 = DP1Call(
        dpVersion: '1.0.0',
        id: 'id',
        slug: 'slug',
        title: 'title',
        created: DateTime.now(),
        items: const [],
        signature: 'sig',
      );
      final ok = await service.castPlaylist(
        mockDevice,
        dp1,
        DP1Intent.displayNow(),
      );
      expect(ok, isFalse);
    });

    test('pause/resume/next/previous/moveTo return ok', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });

      expect(await service.pauseCasting(mockDevice), isTrue);
      expect(await service.resumeCasting(mockDevice), isTrue);
      expect(await service.nextArtwork(mockDevice), isTrue);
      expect(await service.previousArtwork(mockDevice), isTrue);
      expect(await service.moveToArtwork(mockDevice, index: 2), isTrue);
    });

    test('updateDuration returns reply', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': <String, dynamic>{'artworks': <Map<String, dynamic>>[]},
          });

      final reply = await service.updateDuration(mockDevice, const []);
      expect(reply.artworks, isA<List<PlayArtworkV2>>());
    });

    test('sendKeyBoard sends to all devices', () async {
      final device2 = MockFFBluetoothDevice();
      when(() => device2.topicId).thenReturn('topic_id_2');
      when(() => device2.deviceId).thenReturn('remote_device_id_2');
      when(() => device2.name).thenReturn('Remote Device 2');
      when(() => device2.toJson()).thenReturn({
        'deviceId': 'remote_device_id_2',
        'name': 'Remote Device 2',
        'topicId': 'topic_id_2',
      });

      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });

      await service.sendKeyBoard(<BaseDevice>[mockDevice, device2], 13);
      verify(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).called(2);
    });

    test('rotateCanvas returns orientation on success, null on error',
        () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'orientation': 'landscape'},
          });

      final first = await service.rotateCanvas(mockDevice, clockwise: true);
      expect(first, isNotNull);

      // Trigger second path (error -> null)
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenThrow(Exception('rotate fail'));
      final second = await service.rotateCanvas(mockDevice, clockwise: false);
      expect(second, isNull);
    });

    test('updateArtFraming returns ok', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });
      final ok = await service.updateArtFraming(
        mockDevice,
        ArtFraming.fitToScreen,
      );
      expect(ok, isTrue);
    });

    test('updateDisplaySettings completes without throwing', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });
      await service.updateDisplaySettings(
        mockDevice,
        ArtistDisplaySetting(),
        'token123',
      );
    });

    test('updateToLatestVersion completes without throwing', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': <String, dynamic>{},
          });
      await service.updateToLatestVersion(mockDevice);
    });

    test('tap completes without throwing', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });
      await service.tap(<BaseDevice>[mockDevice]);
    });

    test('drag batches and sends after >5 points', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'ok': true},
          });

      // Add 6 drag points to trigger send
      for (var i = 0; i < 6; i++) {
        await service.drag(<BaseDevice>[mockDevice], Offset(i.toDouble(), 0));
      }

      // Allow unawaited future to run
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).called(1);
    });

    test('showPairingQRCode returns true on success, false on error', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {'success': true},
          });

      final success = await service.showPairingQRCode(mockDevice, true);
      expect(success, isTrue);

      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenThrow(Exception('pairing error'));
      final failed = await service.showPairingQRCode(mockDevice, false);
      expect(failed, isFalse);
    });

    test('safeShutdown and safeRestart return true or false appropriately',
        () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': <String, dynamic>{},
          });

      expect(await service.safeShutdown(mockDevice), isTrue);
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenThrow(Exception('shutdown/restart error'));
      expect(await service.safeRestart(mockDevice), isFalse);
    });

    test('getDeviceRealtimeMetrics returns metrics', () async {
      when(() => mockApi.request(
            topicId: any(named: 'topicId'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'message': {
              'cpuUsage': 0.5,
              'memoryUsage': 0.4,
            },
          });

      final metrics = await service.getDeviceRealtimeMetrics(mockDevice);
      expect(metrics, isA<DeviceRealtimeMetrics>());
    });
  });
}
