import 'dart:async';
import 'dart:convert';

// removed unused imports

import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
// removed unused imports
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
// removed unused import
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
// removed unused import
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_dp1_item_data.dart';
import '../unit-tests/mock_data/mock_check_casting_status_reply.dart';
import '../unit-tests/mock_data/mock_ff_bluetooth_device.dart';
import '../unit-tests/mock_data/mock_notification_relayer_message.dart';
import 'fakes/fake_canvas_notification_service.dart';
import 'helper.dart' as test_helper;

class MockNavigationService extends Mock implements NavigationService {}

class MockAuthService extends Mock implements AuthService {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockSettingsDataService extends Mock implements SettingsDataService {}

// Use real FFBluetoothDevice from mock data factory

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

  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(_FakeCanvasDeviceEvent());
  });

  setUp(() {
    navigationService = MockNavigationService();
    authService = MockAuthService();
    configurationService = MockConfigurationService();
    settingsDataService = MockSettingsDataService();
    device = MockFFBluetoothDeviceData.create(
      name: 'My Device',
      remoteID: 'remote-001',
      topicId: 'topic_123',
      deviceId: 'device_123',
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

    // Device is a concrete instance; no stubs required

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

    // Note: Do not stub CanvasDeviceBloc.add on a real bloc to avoid executing
    // real add() during stubbing. We'll trigger updates explicitly in test.
  });

  tearDown(() async {
    // Close test-created streams
    await identityStateController.close();

    // Disconnect all canvas notification services and clear subscriptions
    await CanvasNotificationManager().disconnectAll();

    // Reset current casting device and related state
    await BluetoothDeviceManager().resetDevice();

    // Clear bloc in-memory state
    canvasDeviceBloc.clear();

    // Unregister singletons to avoid leaking state across tests
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

  testWidgets('No device available shows initial state', (tester) async {
    await loadAppFonts();
    when(() => cloudDB.values).thenReturn(<String>[]);

    await tester.pumpWidget(_buildTestWidget());
    await tester.pumpAndSettle();

    final manager = CanvasNotificationManager();
    // Ensure manager knows the active device before any events
    await manager.start();

    await NowDisplayingManager().updateDisplayingNow();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await screenCapture.capture(tester, 'no_device_initial');

    expect(find.byType(NowDisplayingBar), findsOneWidget);
    expect(
        find.textContaining(
            'Pair an FF1 to display your collection and curated art on any screen.'),
        findsOneWidget);
  });

  testWidgets('FF1 connected and get now displaying successful',
      (tester) async {
    await loadAppFonts();
    when(() => cloudDB.values)
        .thenReturn(<String>[jsonEncode(device.toJson())]);
    await tester.pumpWidget(_buildTestWidget());

    final items = MockDP1ItemData.createList(count: 20);
    final index = 10;
    final status =
        MockCheckCastingStatusReply.withItems(items: items, index: index);

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );
    // Ensure manager knows the active device before any events
    await manager.start();
    await manager.connect(device);

    // Emit messages in order, pumping between steps
    fakeService
        .emit(MockNotificationRelayerMessage.connection(isConnected: true));

    fakeService.emit(MockNotificationRelayerMessage.status(reply: status));

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await screenCapture.capture(tester, 'successful_step_1');

    // Assert the item title at the selected index maps correctly in state
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

  testWidgets('Connected is false should show disconnected/idle state',
      (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(_buildTestWidget());
    await tester.pumpAndSettle();

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );

    await manager.start();
    await manager.connect(device);

    // Emit connection = false
    fakeService.emit(
      MockNotificationRelayerMessage.connection(isConnected: false),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await screenCapture.capture(
        tester, 'connected_is_false_show_disconnected_state');

    expect(find.byType(NowDisplayingBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowDisplayingBar),
        matching: find.textContaining('is offline or disconnected.'),
      ),
      findsOneWidget,
    );
  });

  testGoldens('Connected is true but no status emitted', (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(_buildTestWidget());
    await tester.pumpAndSettle();

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );

    await manager.start();
    await manager.connect(device);

    // Emit connection = true, but no status afterwards
    fakeService.emit(
      MockNotificationRelayerMessage.connection(isConnected: true),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await screenCapture.capture(
        tester, 'connected_is_true_but_no_status_emitted');

    expect(find.byType(NowDisplayingBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowDisplayingBar),
        matching:
            find.textContaining('is connected but cannot get now displaying'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Connected but invalid status (empty items)', (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(_buildTestWidget());
    await tester.pumpAndSettle();
    await screenCapture.capture(
        tester, 'now_displaying_invalid_status_empty_items_step_1_initial');

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );

    await manager.start();
    await manager.connect(device);

    fakeService.emit(
      MockNotificationRelayerMessage.connection(isConnected: true),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Emit invalid status with empty items
    final emptyStatus =
        MockCheckCastingStatusReply.withItems(items: const [], index: 0);
    fakeService.emit(
      MockNotificationRelayerMessage.status(reply: emptyStatus),
    );

    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await screenCapture.capture(
        tester, 'connected_but_invalid_status_empty_items');

    expect(find.byType(NowDisplayingBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NowDisplayingBar),
        matching:
            find.textContaining('is connected but cannot get now displaying'),
      ),
      findsOneWidget,
    );
  });
}
