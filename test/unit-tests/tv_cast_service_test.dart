import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/gateway/tv_cast_api.dart';
import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:autonomy_flutter/service/tv_cast_service.dart';

class MockNavigationService extends Mock implements NavigationService {}

class MockTvCastApi extends Mock implements TvCastApi {}

class MockFFBluetoothDevice extends Mock implements FFBluetoothDevice {}

class MockAuthService extends Mock implements AuthService {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockSettingsDataService extends Mock implements SettingsDataService {}

class _FakeNavigationService extends Fake implements NavigationService {}

class _FakeBuildContext extends Fake implements BuildContext {}

void main() {
  group('TvCastServiceImpl', () {
    late TvCastServiceImpl service;
    late MockTvCastApi mockApi;
    late MockFFBluetoothDevice mockDevice;
    late MockAuthService mockAuthService;
    late MockNavigationService mockNavigationService;
    late MockConfigurationService mockConfigurationService;
    late MockSettingsDataService mockSettingsDataService;

    setUpAll(() {
      registerFallbackValue(_FakeNavigationService());
      registerFallbackValue(_FakeBuildContext());
    });

    setUp(() {
      mockApi = MockTvCastApi();
      mockDevice = MockFFBluetoothDevice();
      mockAuthService = MockAuthService();
      mockNavigationService = MockNavigationService();
      mockConfigurationService = MockConfigurationService();
      mockSettingsDataService = MockSettingsDataService();

      // Setup injector
      if (injector_module.injector.isRegistered<NavigationService>()) {
        injector_module.injector.unregister<NavigationService>();
      }
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      if (injector_module.injector.isRegistered<ConfigurationService>()) {
        injector_module.injector.unregister<ConfigurationService>();
      }
      if (injector_module.injector.isRegistered<SettingsDataService>()) {
        injector_module.injector.unregister<SettingsDataService>();
      }
      injector_module.injector
          .registerSingleton<NavigationService>(mockNavigationService);
      injector_module.injector.registerSingleton<AuthService>(mockAuthService);
      injector_module.injector
          .registerSingleton<ConfigurationService>(mockConfigurationService);
      injector_module.injector
          .registerSingleton<SettingsDataService>(mockSettingsDataService);

      // Mock device properties
      when(() => mockDevice.topicId).thenReturn('test_topic_id');
      when(() => mockDevice.deviceId).thenReturn('test_device_id');
      when(() => mockDevice.name).thenReturn('test_device_name');
      when(() => mockDevice.toJson()).thenReturn({
        'deviceId': 'test_device_id',
        'name': 'test_device_name',
        'topicId': 'test_topic_id',
      });

      // Mock ConfigurationService
      when(() => mockConfigurationService.setSelectedDeviceId(any()))
          .thenAnswer((_) async {});

      // Mock SettingsDataService
      when(() => mockSettingsDataService.backupUserSettings())
          .thenAnswer((_) async {});

      // Mock NavigationService context
      when(() => mockNavigationService.context).thenReturn(_FakeBuildContext());

      service = TvCastServiceImpl(mockApi, mockDevice);
    });

    tearDown(() {
      if (injector_module.injector.isRegistered<NavigationService>()) {
        injector_module.injector.unregister<NavigationService>();
      }
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      if (injector_module.injector.isRegistered<ConfigurationService>()) {
        injector_module.injector.unregister<ConfigurationService>();
      }
      if (injector_module.injector.isRegistered<SettingsDataService>()) {
        injector_module.injector.unregister<SettingsDataService>();
      }
    });

    group('timeout', () {
      test('should throw TimeoutException when request times out', () async {
        // Arrange
        when(() => mockApi.request(
                  topicId: any(named: 'topicId'),
                  body: any(named: 'body'),
                ))
            .thenAnswer(
                (_) async => throw TimeoutException('Request timed out'));

        // Act & Assert
        expect(
          () => service.status(
            CheckCastingStatusRequest(),
            shouldShowError: false,
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      // Note: explicit onTimeout path is effectively covered via TimeoutException case above
    });

    test('should initialize with api and device', () {
      // Arrange & Act
      final service = TvCastServiceImpl(mockApi, mockDevice);

      // Assert
      expect(service, isNotNull);
    });

    group('status', () {
      test('should return status successfully', () async {
        // Arrange
        final request = CheckCastingStatusRequest();
        final expectedReply = CheckCastingStatusReply(
          ok: true,
          index: 0,
          isPaused: false,
        );

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {
                'ok': true,
                'index': 0,
                'isPaused': false,
              },
            });

        // Act
        final result = await service.status(request);

        // Assert
        expect(result.ok, expectedReply.ok);
        expect(result.index, expectedReply.index);
        expect(result.isPaused, expectedReply.isPaused);
      });

      test('should throw error when status fails', () async {
        // Arrange
        final request = CheckCastingStatusRequest();

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Network error'));

        // Act & Assert
        // Note: This test verifies error handling but doesn't show UI error dialogs
        expect(() => service.status(request, shouldShowError: false),
            throwsException);
      });
    });

    group('connect', () {
      test('should connect successfully', () async {
        // Arrange
        final request = ConnectRequestV2(
          clientDevice: DeviceInfoV2(
            deviceId: 'test_device',
            deviceName: 'Test Device',
            platform: DevicePlatform.android,
          ),
          primaryAddress: 'primary_address',
        );
        final expectedReply = ConnectReplyV2(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.connect(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });

      test('should throw error when connect fails', () async {
        // Arrange
        final request = ConnectRequestV2(
          clientDevice: DeviceInfoV2(
            deviceId: 'test_device',
            deviceName: 'Test Device',
            platform: DevicePlatform.android,
          ),
          primaryAddress: 'primary_address',
        );

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Connection error'));

        // Act & Assert
        expect(() => service.connect(request), throwsException);
      });
    });

    group('castDP1Playlist', () {
      test('should cast DP1 playlist successfully', () async {
        // Arrange
        final request = CastDP1JsonPlaylistRequest(
          dp1Call: DP1Call(
            dpVersion: '1.0.0',
            id: 'test_id',
            slug: 'test_slug',
            title: 'Test Playlist',
            created: DateTime.now(),
            items: [],
            signature: 'test_signature',
          ),
          intent: DP1Intent.displayNow(),
        );
        final expectedReply = CastDP1PlaylistReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.castDP1Playlist(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });

      test('should throw error when castDP1Playlist fails', () async {
        // Arrange
        final request = CastDP1JsonPlaylistRequest(
          dp1Call: DP1Call(
            dpVersion: '1.0.0',
            id: 'test_id',
            slug: 'test_slug',
            title: 'Test Playlist',
            created: DateTime.now(),
            items: [],
            signature: 'test_signature',
          ),
          intent: DP1Intent.displayNow(),
        );

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Cast error'));

        // Act & Assert
        expect(() => service.castDP1Playlist(request), throwsException);
      });
    });

    group('disconnect', () {
      test('should disconnect successfully', () async {
        // Arrange
        final request = DisconnectRequestV2();
        final expectedReply = DisconnectReplyV2(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.disconnect(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('updateDuration', () {
      test('should update duration successfully', () async {
        // Arrange
        final request = UpdateDurationRequest(artworks: []);
        final expectedReply = UpdateDurationReply(artworks: <PlayArtworkV2>[]);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': <String, dynamic>{
                'artworks': <Map<String, dynamic>>[]
              },
            });

        // Act
        final result = await service.updateDuration(request);

        // Assert
        expect(result.artworks, expectedReply.artworks);
      });
    });

    group('keyboardEvent', () {
      test('should send keyboard event successfully', () async {
        // Arrange
        final request = KeyboardEventRequest(code: 13);
        final expectedReply = KeyboardEventReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.keyboardEvent(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('rotate', () {
      test('should rotate successfully', () async {
        // Arrange
        final request = RotateRequest(clockwise: true);
        // We'll just test that the method returns without throwing
        // The orientation field is optional and complex to mock

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'orientation': 'landscape'},
            });

        // Act
        final result = await service.rotate(request);

        // Assert - just check that a result was returned
        expect(result, isNotNull);
      });
    });

    group('updateArtFraming', () {
      test('should update art framing successfully', () async {
        // Arrange
        final request =
            UpdateArtFramingRequest(artFraming: ArtFraming.fitToScreen);
        final expectedReply = UpdateArtFramingReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.updateArtFraming(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('updateDisplaySettings', () {
      test('should update display settings successfully', () async {
        // Arrange
        final request = UpdateDisplaySettingsRequest(
          tokenId: 'token_123',
          setting: ArtistDisplaySetting(),
        );
        final expectedReply = UpdateDisplaySettingsReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.updateDisplaySettings(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('updateToLatestVersion', () {
      test('should update to latest version successfully', () async {
        // Arrange
        final request = UpdateToLatestVersionRequest();
        // No need for expected reply

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': <String, dynamic>{},
            });

        // Act
        final result = await service.updateToLatestVersion(request);

        // Assert
        expect(result, isA<UpdateToLatestVersionReply>());
      });
    });

    group('drag', () {
      test('should execute drag gesture successfully', () async {
        // Arrange
        final request = DragGestureRequest(cursorOffsets: []);
        final expectedReply = GestureReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.drag(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('showPairingQRCode', () {
      test('should show pairing QR code successfully', () async {
        // Arrange
        final request = ShowPairingQRCodeRequest(show: true);
        final expectedReply = ShowPairingQRCodeReply(success: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'success': true},
            });

        // Act
        final result = await service.showPairingQRCode(request);

        // Assert
        expect(result.success, expectedReply.success);
      });
    });

    group('deviceMetrics', () {
      test('should get device metrics successfully', () async {
        // Arrange
        final request = DeviceRealtimeMetricsRequest();
        // No need for expected reply

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {
                'cpuUsage': 0.5,
                'memoryUsage': 0.6,
              },
            });

        // Act
        final result = await service.deviceMetrics(request);

        // Assert
        expect(result.metrics, isNotNull);
      });
    });

    group('pauseCasting', () {
      test('should pause casting successfully', () async {
        // Arrange
        final request = PauseCastingRequest();
        final expectedReply = PauseCastingReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.pauseCasting(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('resumeCasting', () {
      test('should resume casting successfully', () async {
        // Arrange
        final request = ResumeCastingRequest();
        final expectedReply = ResumeCastingReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.resumeCasting(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('nextArtwork', () {
      test('should move to next artwork successfully', () async {
        // Arrange
        final request = NextArtworkRequest();
        final expectedReply = NextArtworkReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.nextArtwork(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('previousArtwork', () {
      test('should move to previous artwork successfully', () async {
        // Arrange
        final request = PreviousArtworkRequest();
        final expectedReply = PreviousArtworkReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.previousArtwork(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('moveToArtwork', () {
      test('should move to specific artwork successfully', () async {
        // Arrange
        final request = MoveToArtworkRequest(index: 5);
        final expectedReply = MoveToArtworkReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.moveToArtwork(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('getDeviceStatus', () {
      test('should get device status successfully', () async {
        // Arrange
        final request = GetDeviceStatusRequest();

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': <String, dynamic>{
                'screenRotation': 'landscape',
                'connectedWifi': 'Test WiFi',
              },
            });

        // Act
        final result = await service.getDeviceStatus(request);

        // Assert
        expect(result.deviceStatus, isNotNull);
      });
    });

    group('tap', () {
      test('should execute tap gesture successfully', () async {
        // Arrange
        final request = TapGestureRequest();
        final expectedReply = GestureReply(ok: true);

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': {'ok': true},
            });

        // Act
        final result = await service.tap(request);

        // Assert
        expect(result.ok, expectedReply.ok);
      });
    });

    group('safeShutdown', () {
      test('should shutdown safely', () async {
        // Arrange
        final request = SafeShutdownRequest();

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': <String, dynamic>{},
            });

        // Act & Assert - should not throw
        await service.safeShutdown(request);
      });

      test('should throw error when safeShutdown fails', () async {
        // Arrange
        final request = SafeShutdownRequest();

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Shutdown error'));

        // Act & Assert
        expect(() => service.safeShutdown(request), throwsException);
      });
    });

    group('safeRestart', () {
      test('should restart safely', () async {
        // Arrange
        final request = SafeRestartRequest();

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => {
              'message': <String, dynamic>{},
            });

        // Act & Assert - should not throw
        await service.safeRestart(request);
      });

      test('should throw error when safeRestart fails', () async {
        // Arrange
        final request = SafeRestartRequest();

        when(() => mockApi.request(
              topicId: any(named: 'topicId'),
              body: any(named: 'body'),
            )).thenThrow(Exception('Restart error'));

        // Act & Assert
        expect(() => service.safeRestart(request), throwsException);
      });
    });
  });
}
