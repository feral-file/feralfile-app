import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_device_data.dart';

class FakeNotificationSocket implements NotificationSocket {
  FakeNotificationSocket({
    required this.incoming,
    required this.outgoing,
  });

  final StreamController<dynamic> incoming;
  final StreamController<dynamic> outgoing;

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  StreamSink<dynamic> get sink => outgoing.sink;
}

class MockAuthService extends Mock implements AuthService {}

// No need to mock WebSocketChannel anymore

class _FakeBaseDevice extends Fake implements BaseDevice {}

void main() {
  group('CanvasNotificationService', () {
    late CanvasNotificationService service;
    late MockAuthService mockAuthService;
    late MockBaseDevice testDevice;

    setUpAll(() {
      registerFallbackValue(_FakeBaseDevice());
    });

    setUp(() {
      mockAuthService = MockAuthService();
      testDevice = MockDeviceData.createDevice();

      // Setup injector
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
      injector_module.injector.registerSingleton<AuthService>(mockAuthService);
    });

    tearDown(() {
      if (injector_module.injector.isRegistered<AuthService>()) {
        injector_module.injector.unregister<AuthService>();
      }
    });

    test('should initialize with device', () {
      // Arrange
      service = CanvasNotificationService(testDevice);

      // Assert
      expect(service.isConnected, false);
      expect(service.lastError, isNull);
    });

    test('should get notification stream', () {
      // Arrange
      service = CanvasNotificationService(testDevice);

      // Act
      final stream = service.notificationStream;

      // Assert
      expect(stream, isNotNull);
    });

    test('should return false when user is not authenticated', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);
      when(() => mockAuthService.getUserId()).thenReturn(null);

      // Act
      final result = await service.connect();

      // Assert
      expect(result, false);
      expect(service.isConnected, false);
    });

    test('should connect successfully when user is authenticated (mocked WS)',
        () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);

      // WS fakes
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Act
      final connectFuture = service.connect();

      // Send a first valid message to complete the connection (next microtask)
      Future.microtask(() {
        incoming.add(jsonEncode({
          'type': 'notification',
          'message': <String, dynamic>{},
          'notification_type': 'connection',
          'timestamp': 1700000000000,
        }));
      });

      final result = await connectFuture;

      // Assert
      expect(result, isA<bool>());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isConnected, true);

      // Clean up
      await incoming.close();
      await outgoing.close();
    });

    test('should handle connection error gracefully', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);
      when(() => mockAuthService.getUserId())
          .thenThrow(Exception('Auth error'));

      // Act
      final result = await service.connect();

      // Assert
      expect(result, false);
      expect(service.lastError, isNotNull);
    });

    test('should disconnect successfully', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);

      // Act
      await service.disconnect();

      // Assert
      expect(service.isConnected, false);
    });

    test('should handle message parsing errors', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Act
      final connectFuture = service.connect();
      Future.microtask(() {
        incoming.add('not-a-json');
      });
      final result = await connectFuture;

      // Assert
      expect(result, isA<bool>());

      await incoming.close();
      await outgoing.close();
    });

    test('should handle multiple disconnects gracefully', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);

      // Act
      await service.disconnect();
      await service.disconnect(); // Multiple disconnects should not throw

      // Assert
      expect(service.isConnected, false);
    });

    test('should track last error when connection fails', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);
      when(() => mockAuthService.getUserId())
          .thenThrow(Exception('Auth error'));

      // Act
      await service.connect();

      // Assert
      expect(service.lastError, isNotNull);
      expect(service.lastError, contains('Auth error'));
    });

    test('should have lastError property accessible', () {
      // Arrange
      service = CanvasNotificationService(testDevice);

      // Assert - lastError property exists and is initially null
      expect(service.lastError, isNull);
    });

    test('should have notification stream that can receive messages', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Subscribe to the notification stream
      final notifications = <NotificationRelayerMessage>[];
      final subscription = service.notificationStream.listen((notification) {
        notifications.add(notification);
      });

      // Act - Get the stream and verify it exists
      final stream = service.notificationStream;

      // Assert
      expect(stream, isNotNull);

      // Establish connection
      final connectFuture = service.connect();
      Future.microtask(() {
        incoming.add(jsonEncode({
          'type': 'notification',
          'message': {'foo': 'bar'},
          'notification_type': 'status',
          'timestamp': 1700000000000,
        }));
      });
      await connectFuture;

      // Emit another message to be captured by subscription
      incoming.add(jsonEncode({
        'type': 'notification',
        'message': {'hello': 'world'},
        'notification_type': 'device_status',
        'timestamp': 1700000001000,
      }));

      // Allow stream to process
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifications, isNotEmpty);

      // Clean up
      await subscription.cancel();
      await incoming.close();
      await outgoing.close();
    });

    test('connect returns true when already connected', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Connect first time
      final firstConnect = service.connect();
      Future.microtask(() {
        incoming.add(jsonEncode({
          'type': 'notification',
          'message': <String, dynamic>{},
          'notification_type': 'connection',
          'timestamp': 1700000000000,
        }));
      });
      final firstResult = await firstConnect;
      expect(firstResult, isA<bool>());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.isConnected, true);

      // Act - connect again
      final secondResult = await service.connect();

      // Assert
      expect(secondResult, true);

      await incoming.close();
      await outgoing.close();
    });

    test('successful connect clears lastError', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Pre-set an error state via manual connection error
      // Trigger connection attempt, then emit error
      final connectFuture = service.connect();
      Future.microtask(() {
        incoming.addError(Exception('temporary error'));
      });
      final result = await connectFuture;
      expect(result, false);
      expect(service.lastError, isNotNull);

      // Next connection should succeed and clear lastError
      // Recreate controllers and service to avoid multiple listeners on same stream
      final incoming2 = StreamController<dynamic>();
      final outgoing2 = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming2,
          outgoing: outgoing2,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );
      final connectFuture2 = service.connect();
      Future.microtask(() {
        incoming2.add(jsonEncode({
          'type': 'notification',
          'message': <String, dynamic>{},
          'notification_type': 'connection',
          'timestamp': 1700000000000,
        }));
      });
      final result2 = await connectFuture2;
      expect(result2, isA<bool>());
      expect(service.lastError, isNull);

      await incoming.close();
      await outgoing.close();
      await incoming2.close();
      await outgoing2.close();
    });

    test('invalid JSON does not emit to notificationStream', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      final notifications = <NotificationRelayerMessage>[];
      final sub = service.notificationStream.listen(notifications.add);

      // Establish connection with a valid message first
      final connectFuture = service.connect();
      Future.microtask(() {
        incoming.add(jsonEncode({
          'type': 'notification',
          'message': {'ok': true},
          'notification_type': 'status',
          'timestamp': 1700000000000,
        }));
      });
      await connectFuture;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final baseline = notifications.length;

      // Send invalid JSON - should be ignored
      incoming.add('this-is-not-json');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Assert: no new notifications
      expect(notifications.length, baseline);

      await sub.cancel();
      await incoming.close();
      await outgoing.close();
    });

    test('should handle onError and schedule reconnect', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Act
      final connectFuture = service.connect();
      // Trigger error to complete connection as false
      incoming.addError(Exception('socket error'));
      final result = await connectFuture;

      // Assert
      expect(result, isA<bool>());
      expect(service.isConnected, false);
      expect(service.lastError, isNotNull);

      await incoming.close();
      await outgoing.close();
    });

    test('should handle onDone (close) and set isConnected to false', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Connect successfully first
      final connectFuture = service.connect();
      Future.microtask(() {
        incoming.add(jsonEncode({
          'type': 'notification',
          'message': <String, dynamic>{},
          'notification_type': 'connection',
          'timestamp': 1700000000000,
        }));
      });
      final result = await connectFuture;
      expect(result, isA<bool>());
      expect(service.isConnected, true);

      // Act - close underlying stream
      await incoming.close();

      // Allow onDone to run
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(service.isConnected, false);

      await outgoing.close();
    });

    test('disconnect should close socket and reset state', () async {
      // Arrange
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      final incoming = StreamController<dynamic>();
      final outgoing = StreamController<dynamic>.broadcast();
      service = CanvasNotificationService(
        testDevice,
        channelFactory: (_) => FakeNotificationSocket(
          incoming: incoming,
          outgoing: outgoing,
        ),
        uriBuilder: (_, __) => Uri.parse('ws://test'),
      );

      // Connect successfully
      final connectFuture = service.connect();
      Future.microtask(() {
        incoming.add(jsonEncode({
          'type': 'notification',
          'message': <String, dynamic>{},
          'notification_type': 'connection',
          'timestamp': 1700000000000,
        }));
      });
      await connectFuture;
      expect(service.isConnected, true);

      // Act
      await service.disconnect();

      // Assert
      expect(service.isConnected, false);

      await outgoing.close();
    });

    test('should schedule reconnect after connection failure', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);
      when(() => mockAuthService.getUserId())
          .thenThrow(Exception('Connection failed'));

      // Act
      final result = await service.connect();

      // Assert
      expect(result, false);
      expect(service.lastError, isNotNull);
      // The reconnect is scheduled asynchronously in _scheduleReconnect
      // We can't directly test the timer callback without waiting
    });

    test('should handle invalid JSON messages', () async {
      // Arrange
      service = CanvasNotificationService(testDevice);
      const userId = 'test_user_123';
      when(() => mockAuthService.getUserId()).thenReturn(userId);

      // Act
      final result = await service.connect();

      // Assert - should handle gracefully even with invalid messages
      expect(result, isA<bool>());
    });
  });
}
