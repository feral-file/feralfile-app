import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart' as injector_module;
import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
// removed unused import
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/settings_data_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_dp1_item_data.dart';
import '../unit-tests/mock_data/mock_check_casting_status_reply.dart';
import '../unit-tests/mock_data/mock_ff_bluetooth_device.dart';
import '../unit-tests/mock_data/mock_notification_relayer_message.dart';
// removed unused import
import 'fakes/fake_canvas_notification_service.dart';
import 'helper.dart' as test_helper;

class MockCanvasClientServiceV2 extends Mock implements CanvasClientServiceV2 {}

class MockCloudManager extends Mock implements CloudManager {}

class MockCloudDB extends Mock implements CloudDB {}

class MockAuthService extends Mock implements AuthService {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockSettingsDataService extends Mock implements SettingsDataService {}

class _MockNftTokensService extends Mock implements NftTokensService {}

class MockIdentityBloc extends Mock implements IdentityBloc {}

class _FakeBuildContext extends Fake implements BuildContext {}

class _FakeCanvasDeviceEvent extends Fake implements CanvasDeviceEvent {}

class _FakeDP1Call extends Fake implements DP1Call {}

class _FakeDP1Intent extends Fake implements DP1Intent {}

const String prefix = 'dp1_playlist_details';

final test_helper.ScreenCapture screenCapture =
    test_helper.ScreenCapture(prefix);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FFBluetoothDevice device;
  late CanvasDeviceBloc canvasDeviceBloc;
  late MockCanvasClientServiceV2 mockCanvasClientServiceV2;
  late MockCloudManager cloudManager;
  late MockCloudDB cloudDB;
  late MockAuthService authService;
  late MockConfigurationService configurationService;
  late MockSettingsDataService settingsDataService;
  late _MockNftTokensService mockNftTokensService;
  late MockIdentityBloc mockIdentityBloc;
  late StreamController<IdentityState> identityStateController;

  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(_FakeCanvasDeviceEvent());
    registerFallbackValue(_FakeDP1Call());
    registerFallbackValue(_FakeDP1Intent());
  });

  setUp(() {
    device = MockFFBluetoothDeviceData.create(
      name: 'My Device',
      remoteID: 'remote-001',
      topicId: 'topic_123',
      deviceId: 'device_123',
    );
    mockCanvasClientServiceV2 = MockCanvasClientServiceV2();
    canvasDeviceBloc = CanvasDeviceBloc(mockCanvasClientServiceV2);
    cloudManager = MockCloudManager();
    cloudDB = MockCloudDB();

    // Reset and register DI
    if (injector_module.injector.isRegistered<CanvasDeviceBloc>()) {
      injector_module.injector.unregister<CanvasDeviceBloc>();
    }
    if (injector_module.injector.isRegistered<CloudManager>()) {
      injector_module.injector.unregister<CloudManager>();
    }
    if (injector_module.injector.isRegistered<SubscriptionBloc>()) {
      injector_module.injector.unregister<SubscriptionBloc>();
    }
    if (injector_module.injector.isRegistered<FeralFileFeedManager>()) {
      injector_module.injector.unregister<FeralFileFeedManager>();
    }

    injector_module.injector
        .registerSingleton<CanvasDeviceBloc>(canvasDeviceBloc);
    injector_module.injector.registerSingleton<CloudManager>(cloudManager);
    injector_module.injector.registerSingleton<SubscriptionBloc>(
      SubscriptionBloc(),
    );
    injector_module.injector
        .registerSingleton<FeralFileFeedManager>(FeralFileFeedManager());
    mockNftTokensService = _MockNftTokensService();
    mockIdentityBloc = MockIdentityBloc();
    identityStateController = StreamController<IdentityState>.broadcast();
    identityStateController.add(IdentityState({}));
    // Register required services used by CanvasNotificationService and BluetoothDeviceManager
    authService = MockAuthService();
    configurationService = MockConfigurationService();
    settingsDataService = MockSettingsDataService();

    if (injector_module.injector.isRegistered<AuthService>()) {
      injector_module.injector.unregister<AuthService>();
    }
    if (injector_module.injector.isRegistered<ConfigurationService>()) {
      injector_module.injector.unregister<ConfigurationService>();
    }
    if (injector_module.injector.isRegistered<SettingsDataService>()) {
      injector_module.injector.unregister<SettingsDataService>();
    }
    injector_module.injector.registerSingleton<AuthService>(authService);
    injector_module.injector
        .registerSingleton<ConfigurationService>(configurationService);
    injector_module.injector
        .registerSingleton<SettingsDataService>(settingsDataService);
    if (injector_module.injector.isRegistered<NftTokensService>()) {
      injector_module.injector.unregister<NftTokensService>();
    }
    if (injector_module.injector.isRegistered<IdentityBloc>()) {
      injector_module.injector.unregister<IdentityBloc>();
    }
    injector_module.injector
        .registerSingleton<NftTokensService>(mockNftTokensService);
    injector_module.injector.registerSingleton<IdentityBloc>(mockIdentityBloc);

    when(() => cloudManager.ffDeviceDB).thenReturn(cloudDB);
    when(() => cloudDB.values)
        .thenReturn(<String>[jsonEncode(device.toJson())]);
    when(() => authService.getUserId()).thenReturn('user_1');
    when(() => configurationService.setSelectedDeviceId(any()))
        .thenAnswer((_) async {});
    when(() => settingsDataService.backupUserSettings())
        .thenAnswer((_) async {});
    when(() => mockIdentityBloc.state).thenReturn(IdentityState({}));
    when(() => mockIdentityBloc.stream)
        .thenAnswer((_) => identityStateController.stream);
    when(() => mockNftTokensService.getManualTokens(
          indexerIds: any(named: 'indexerIds'),
          shouldCallIndexer: any(named: 'shouldCallIndexer'),
        )).thenAnswer((_) async => <AssetToken>[]);
    // Cast playlist calls always succeed
    when(() => mockCanvasClientServiceV2.castPlaylist(
          device,
          any(that: isA<DP1Call>()),
          any(that: isA<DP1Intent>()),
          usingUrl: any(named: 'usingUrl'),
        )).thenAnswer((_) async => true);
  });

  Widget _buildTestWidget(DP1PlaylistDetailsScreenPayload payload) =>
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CanvasDeviceBloc>.value(value: canvasDeviceBloc),
            BlocProvider<SubscriptionBloc>.value(
              value: injector_module.injector.get<SubscriptionBloc>(),
            ),
          ],
          child: RepaintBoundary(
            key: const Key('shotRoot'),
            child: Scaffold(
              body: Stack(
                children: [
                  DP1PlaylistDetailsScreen(payload: payload),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: const NowDisplayingBar(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('Display from playlist updates NowDisplayingBar', (tester) async {
    await loadAppFonts();

    final items = MockDP1ItemData.createList(count: 10);
    final playlist = DP1Call(
      dpVersion: '1.0.0',
      id: 'playlist_001',
      slug: 'playlist-001',
      title: 'My Playlist',
      created: DateTime.now(),
      items: items,
      signature: 'sig',
    );
    final playlistRef =
        PlaylistReference(playlist: playlist, url: 'https://example.com');

    final fakeService = FakeCanvasNotificationService(device);
    final manager = CanvasNotificationManager(
      serviceFactory: (_) => fakeService,
    );

    when(() => mockCanvasClientServiceV2.castPlaylist(
          device,
          any(that: isA<DP1Call>()),
          any(that: isA<DP1Intent>()),
          usingUrl: any(named: 'usingUrl'),
        )).thenAnswer((_) async {
      fakeService.emit(MockNotificationRelayerMessage.status(
          reply:
              MockCheckCastingStatusReply.withItems(items: items, index: 0)));
      return true;
    });

    await manager.start();
    await manager.connect(device);

    // Prepare playlist

    final payload = DP1PlaylistDetailsScreenPayload(playlist: playlistRef);

    await tester.pumpWidget(_buildTestWidget(payload));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await screenCapture.capture(tester, 'dp1_playlist_details_step_1');

    // Mark device as connected so FFCastButton appears
    fakeService.emit(
      MockNotificationRelayerMessage.connection(isConnected: true),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await screenCapture.capture(tester, 'dp1_playlist_details_step_2');

    // Tap Display (Play) button
    expect(find.byType(FFCastButton), findsOneWidget);
    await tester.tap(find.byType(FFCastButton));

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await screenCapture.capture(tester, 'dp1_playlist_details_step_3');

    // Assert NowDisplayingBar shows the selected item title
    final expectedItem = items[0];
    final expectedTitle = expectedItem.title ?? '';
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
