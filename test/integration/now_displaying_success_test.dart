import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_dp1_item_data.dart';
import '../unit-tests/mock_data/mock_check_casting_status_reply.dart';
import '../unit-tests/mock_data/mock_notification_relayer_message.dart';
import 'fakes/fake_canvas_notification_service.dart';
import 'helper.dart' as test_helper;

class MockNavigationService extends Mock implements NavigationService {}

class MockAuthService extends Mock implements AuthService {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockSettingsDataService extends Mock implements SettingsDataService {}

class MockCanvasClientServiceV2 extends Mock implements CanvasClientServiceV2 {}

class MockCloudManager extends Mock implements CloudManager {}

class MockCloudDB extends Mock implements CloudDB {}

class _MockNftTokensService extends Mock implements NftTokensService {}

class MockIdentityBloc extends Mock implements IdentityBloc {}

class _FakeBuildContext extends Fake implements BuildContext {}

class _FakeCanvasDeviceEvent extends Fake implements CanvasDeviceEvent {}

const String prefix = 'now_displaying';

final test_helper.ScreenCapture screenCapture =
    test_helper.ScreenCapture(prefix);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNavigationService navigationService;
  late MockAuthService authService;
  late MockConfigurationService configurationService;
  late MockSettingsDataService settingsDataService;
  late FFBluetoothDevice device;
  late CanvasDeviceBloc canvasDeviceBloc;
  late MockCanvasClientServiceV2 mockCanvasClientServiceV2;
  late MockCloudManager cloudManager;
  late MockCloudDB cloudDB;
  late _MockNftTokensService mockNftTokensService;
  late MockIdentityBloc mockIdentityBloc;
  late StreamController<IdentityState> identityStateController;

  setUp(() {
    // Register fallback values locally per-test to avoid shared state
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(_FakeCanvasDeviceEvent());
    navigationService = MockNavigationService();
    authService = MockAuthService();
    configurationService = MockConfigurationService();
    settingsDataService = MockSettingsDataService();
    device = FFBluetoothDevice(
      name: 'My Device',
      remoteID: 'remote-001',
      topicId: 'topic_123',
      deviceId: 'device_123',
      branchName: 'release',
    );
    mockCanvasClientServiceV2 = MockCanvasClientServiceV2();
    canvasDeviceBloc = CanvasDeviceBloc(mockCanvasClientServiceV2);
    mockNftTokensService = _MockNftTokensService();
    cloudManager = MockCloudManager();
    cloudDB = MockCloudDB();
    mockIdentityBloc = MockIdentityBloc();
    identityStateController = StreamController<IdentityState>.broadcast();
    identityStateController.add(IdentityState({}));

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
    if (injector_module.injector.isRegistered<NftTokensService>()) {
      injector_module.injector.unregister<NftTokensService>();
    }
    if (injector_module.injector.isRegistered<IdentityBloc>()) {
      injector_module.injector.unregister<IdentityBloc>();
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
    injector_module.injector
        .registerSingleton<NftTokensService>(mockNftTokensService);
    injector_module.injector.registerSingleton<IdentityBloc>(mockIdentityBloc);

    when(() => navigationService.context).thenReturn(_FakeBuildContext());
    when(() => configurationService.setSelectedDeviceId(any()))
        .thenAnswer((_) async {});
    when(() => settingsDataService.backupUserSettings())
        .thenAnswer((_) async {});
    when(() => authService.getUserId()).thenReturn('user_1');
    when(() => cloudManager.ffDeviceDB).thenReturn(cloudDB);
    when(() => cloudDB.values)
        .thenReturn(<String>[jsonEncode(device.toJson())]);
    when(() => mockNftTokensService.getManualTokens(
          indexerIds: any(named: 'indexerIds'),
          shouldCallIndexer: any(named: 'shouldCallIndexer'),
        )).thenAnswer((_) async => <AssetToken>[]);
    when(() => mockIdentityBloc.state).thenReturn(IdentityState({}));
    when(() => mockIdentityBloc.stream)
        .thenAnswer((_) => identityStateController.stream);
  });

  tearDown(() async {
    await identityStateController.close();
    CanvasNotificationManager().dispose();
    await BluetoothDeviceManager().resetDevice();
    canvasDeviceBloc.clear();

    if (injector_module.injector.isRegistered<CanvasDeviceBloc>()) {
      injector_module.injector.unregister<CanvasDeviceBloc>();
    }
    if (injector_module.injector.isRegistered<CloudManager>()) {
      injector_module.injector.unregister<CloudManager>();
    }
    if (injector_module.injector.isRegistered<NftTokensService>()) {
      injector_module.injector.unregister<NftTokensService>();
    }
    if (injector_module.injector.isRegistered<IdentityBloc>()) {
      injector_module.injector.unregister<IdentityBloc>();
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
    if (injector_module.injector.isRegistered<NavigationService>()) {
      injector_module.injector.unregister<NavigationService>();
    }
  });

  Widget _buildTestWidget() => MaterialApp(
        home: BlocProvider<CanvasDeviceBloc>.value(
          value: canvasDeviceBloc,
          child: RepaintBoundary(
            key: const Key('shotRoot'),
            child: const Scaffold(body: NowDisplayingBar()),
          ),
        ),
      );

  testWidgets('FF1 connected and get now displaying successful',
      (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(_buildTestWidget());

    final items = MockDP1ItemData.createList(count: 20);
    final index = 10;
    final status =
        MockCheckCastingStatusReply.withItems(items: items, index: index);

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );
    await manager.start();
    await manager.connect(device);

    fakeService
        .emit(MockNotificationRelayerMessage.connection(isConnected: true));
    fakeService.emit(MockNotificationRelayerMessage.status(reply: status));

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    await screenCapture.capture(tester, 'successful_step_1');

    final expectedTitle = items[index].title ?? '';
    expect(find.byType(NowDisplayingBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowDisplayingBar),
        matching: find.textContaining(expectedTitle),
      ),
      findsOneWidget,
    );
  });
}


