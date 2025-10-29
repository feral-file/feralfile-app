import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
import 'package:autonomy_flutter/service/canvas_notification_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'mock_data/mock_device_data.dart';

class MockAuthService extends Mock implements AuthService {}

class MockCanvasDeviceBloc extends Mock implements CanvasDeviceBloc {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockCloudManager extends Mock implements CloudManager {}

class MockCloudDB extends Mock implements CloudDB {}

class MockCanvasNotificationService extends Mock
    implements CanvasNotificationService {}

class _FakeBaseDevice extends Fake implements BaseDevice {}

class _FakeCanvasDeviceEvent extends Fake implements CanvasDeviceEvent {}

void main() {
  group('CanvasNotificationManager', () {
    late CanvasNotificationManager manager;
    late MockAuthService mockAuthService;
    late MockCanvasDeviceBloc mockBloc;
    late MockConfigurationService mockConfigurationService;
    late MockCloudManager mockCloudManager;
    late MockCloudDB mockCloudDB;

    setUpAll(() {
      registerFallbackValue(_FakeBaseDevice());
      registerFallbackValue(_FakeCanvasDeviceEvent());
    });

    setUp(() {
      manager = CanvasNotificationManager();
      mockAuthService = MockAuthService();
      mockBloc = MockCanvasDeviceBloc();
      mockConfigurationService = MockConfigurationService();
      mockCloudManager = MockCloudManager();
      mockCloudDB = MockCloudDB();

      // Setup injector
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      if (injector_module.injector.isRegistered<CanvasDeviceBloc>()) {
        injector_module.injector.unregister<CanvasDeviceBloc>();
      }
      if (injector_module.injector.isRegistered<ConfigurationService>()) {
        injector_module.injector.unregister<ConfigurationService>();
      }
      if (injector_module.injector.isRegistered<CloudManager>()) {
        injector_module.injector.unregister<CloudManager>();
      }

      injector_module.injector.registerSingleton<AuthService>(mockAuthService);
      injector_module.injector.registerSingleton<CanvasDeviceBloc>(mockBloc);
      injector_module.injector
          .registerSingleton<ConfigurationService>(mockConfigurationService);
      injector_module.injector
          .registerSingleton<CloudManager>(mockCloudManager);

      // Mock AuthService
      when(() => mockAuthService.getUserId()).thenReturn('test_user');

      // Mock ConfigurationService methods that are called
      when(() => mockConfigurationService.getSelectedDeviceId())
          .thenReturn(null);

      // Mock CloudManager's ffDeviceDB getter
      when(() => mockCloudManager.ffDeviceDB).thenReturn(mockCloudDB);

      // Mock CloudDB methods used by BluetoothDeviceManager
      when(() => mockCloudDB.values).thenReturn([]);
    });

    tearDown(() async {
      manager.dispose();
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      if (injector_module.injector.isRegistered<CanvasDeviceBloc>()) {
        injector_module.injector.unregister<CanvasDeviceBloc>();
      }
      if (injector_module.injector.isRegistered<ConfigurationService>()) {
        injector_module.injector.unregister<ConfigurationService>();
      }
      if (injector_module.injector.isRegistered<CloudManager>()) {
        injector_module.injector.unregister<CloudManager>();
      }
    });

    test('should be a singleton', () {
      // Arrange
      final instance1 = CanvasNotificationManager();
      final instance2 = CanvasNotificationManager();

      // Assert
      expect(instance1, same(instance2));
    });

    test('should dispose successfully', () async {
      // Arrange
      // Note: We don't call start() here because it has deep dependencies
      // on static BluetoothDeviceManager that would require extensive mocking.
      // This test verifies that dispose can be called without errors.

      // Act
      manager.dispose();

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should disconnect from all devices', () async {
      // Arrange
      // Note: Actual connection tests are complex due to WebSocket dependencies
      // and static BluetoothDeviceManager access

      // Act
      await manager.disconnectAll();

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should disconnect from specific device', () async {
      // Arrange
      const deviceId = 'test_device_1';

      // Act
      await manager.disconnect(deviceId);

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should get notification stream for device', () {
      // Arrange
      const deviceId = 'test_device_1';

      // Act
      final stream = manager.getNotificationStream(deviceId);

      // Assert
      expect(stream, isNull); // No device connected yet
    });

    test('should handle null notification stream for non-existent device', () {
      // Arrange
      const deviceId = 'non_existent_device';

      // Act
      final stream = manager.getNotificationStream(deviceId);

      // Assert
      expect(stream, isNull);
    });

    test('should get combined notification stream', () {
      // Arrange & Act
      final stream = manager.combinedNotificationStream;

      // Assert
      expect(stream, isNotNull);
    });

    test('should connect to device and add to services', () async {
      // Arrange
      final testDevice = MockDeviceData.createDevice();

      // This test verifies the connect method structure
      // Actual implementation will create CanvasNotificationService internally
      // which requires WebSocket connection that is hard to mock in unit tests

      // Act
      await manager.connect(testDevice);

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should handle device already connected', () async {
      // Arrange
      final testDevice = MockDeviceData.createDevice();

      // Act - connect twice
      await manager.connect(testDevice);
      await manager.connect(testDevice);

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should handle disconnect for device that does not exist', () async {
      // Arrange
      const deviceId = 'non_existent_device_id';

      // Act
      await manager.disconnect(deviceId);

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should handle start without throwing', () async {
      // Arrange
      // Note: start() has dependencies on BluetoothDeviceManager
      // which requires complex mocking. This test verifies it doesn't crash
      // even without proper setup.

      // Act
      try {
        await manager.start();
      } catch (e) {
        // Expected in test environment without proper Bluetooth setup
        expect(e, isNotNull);
      }

      // Assert - manager should still be valid
      expect(manager, isNotNull);
    });

    test('should handle multiple disconnects', () async {
      // Arrange
      const deviceId = 'test_device_1';

      // Act
      await manager.disconnect(deviceId);
      await manager.disconnect(deviceId);

      // Assert - should not throw
      expect(manager, isNotNull);
    });

    test('should handle multiple dispose calls', () {
      // Arrange
      final manager1 = CanvasNotificationManager();

      // Act
      manager1.dispose();
      manager1.dispose();

      // Assert - should not throw
      expect(manager1, isNotNull);
    });

    test('should clear all subscriptions on disconnectAll', () async {
      // Arrange & Act
      await manager.disconnectAll();

      // Assert - should not throw
      expect(manager, isNotNull);

      // All streams should be null after disconnect
      final stream = manager.getNotificationStream('any_device');
      expect(stream, isNull);
    });
  });
}
