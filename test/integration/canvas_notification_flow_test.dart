import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
import 'package:autonomy_flutter/service/canvas_notification_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockNavigationService extends Mock implements NavigationService {}

class MockAuthService extends Mock implements AuthService {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockSettingsDataService extends Mock implements SettingsDataService {}

class MockFFBluetoothDevice extends Mock implements FFBluetoothDevice {}

class MockCanvasDeviceBloc extends Mock implements CanvasDeviceBloc {}

class MockCloudManager extends Mock implements CloudManager {}

class MockCloudDB extends Mock implements CloudDB {}

class _FakeBuildContext extends Fake implements BuildContext {}

class _FakeCanvasDeviceEvent extends Fake implements CanvasDeviceEvent {}

class FakeCanvasNotificationService extends CanvasNotificationService {
  FakeCanvasNotificationService(BaseDevice device)
      : _controller = StreamController<NotificationRelayerMessage>.broadcast(),
        super(device);

  final StreamController<NotificationRelayerMessage> _controller;
  bool _connected = false;

  void emit(NotificationRelayerMessage message) => _controller.add(message);

  @override
  Stream<NotificationRelayerMessage> get notificationStream =>
      _controller.stream;

  @override
  Future<bool> connect() async {
    _connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _controller.close();
  }

  @override
  bool get isConnected => _connected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNavigationService navigationService;
  late MockAuthService authService;
  late MockConfigurationService configurationService;
  late MockSettingsDataService settingsDataService;
  late MockFFBluetoothDevice device;
  late MockCanvasDeviceBloc canvasDeviceBloc;
  late MockCloudManager cloudManager;
  late MockCloudDB cloudDB;

  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(_FakeCanvasDeviceEvent());
  });

  setUp(() {
    navigationService = MockNavigationService();
    authService = MockAuthService();
    configurationService = MockConfigurationService();
    settingsDataService = MockSettingsDataService();
    device = MockFFBluetoothDevice();
    canvasDeviceBloc = MockCanvasDeviceBloc();
    cloudManager = MockCloudManager();
    cloudDB = MockCloudDB();

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
    if (injector_module.injector.isRegistered<CanvasDeviceBloc>()) {
      injector_module.injector.unregister<CanvasDeviceBloc>();
    }
    if (injector_module.injector.isRegistered<CloudManager>()) {
      injector_module.injector.unregister<CloudManager>();
    }
    injector_module.injector
        .registerSingleton<NavigationService>(navigationService);
    injector_module.injector.registerSingleton<AuthService>(authService);
    injector_module.injector
        .registerSingleton<ConfigurationService>(configurationService);
    injector_module.injector
        .registerSingleton<SettingsDataService>(settingsDataService);
    injector_module.injector
        .registerSingleton<CanvasDeviceBloc>(canvasDeviceBloc);
    injector_module.injector.registerSingleton<CloudManager>(cloudManager);

    when(() => device.topicId).thenReturn('topic_123');
    when(() => device.deviceId).thenReturn('device_123');
    when(() => device.name).thenReturn('My Device');

    when(() => navigationService.context).thenReturn(_FakeBuildContext());
    when(() => configurationService.setSelectedDeviceId(any()))
        .thenAnswer((_) async {});
    when(() => settingsDataService.backupUserSettings())
        .thenAnswer((_) async {});
    when(() => authService.getUserId()).thenReturn('user_1');
    when(() => cloudManager.ffDeviceDB).thenReturn(cloudDB);
    when(() => cloudDB.values).thenReturn(<String>[]);
  });

  testWidgets(
      'start() receives status and dispatches CanvasDeviceUpdateCastingStatusEvent (VM UI shell)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CanvasDeviceBloc>.value(
          value: canvasDeviceBloc,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );

    await manager.start();
    await manager.connect(device);

    final status = CheckCastingStatusReply(ok: true, index: 0, isPaused: false);
    final message = NotificationRelayerMessage(
      type: RelayerMessageType.notification,
      notificationType: RelayerNotificationType.status,
      timestamp: DateTime.now(),
      message: status.toJson(),
    );

    fakeService.emit(message);

    await tester.pump(const Duration(milliseconds: 50));
    verify(() => canvasDeviceBloc
        .add(any(that: isA<CanvasDeviceUpdateCastingStatusEvent>()))).called(1);
  });
}
