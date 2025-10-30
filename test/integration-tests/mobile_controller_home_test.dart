import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/index.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/header.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockFeralFileFeedManager extends Mock implements FeralFileFeedManager {}

class MockBaseDP1FeedService extends Mock implements BaseDP1FeedServiceImpl {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFeralFileFeedManager mockFeedManager;
  late MockBaseDP1FeedService mockFeedService;
  late ChannelsBloc channelsBloc;
  late PlaylistsBloc playlistsBloc;

  // Test data
  final testChannels = [
    ChannelReference(
      channel: Channel(
        id: 'channel1',
        title: 'Test Channel 1',
        slug: 'test-channel-1',
        created: DateTime(2025, 1, 1),
        playlists: <String>[],
      ),
      url: 'https://test.com',
    ),
    ChannelReference(
      channel: Channel(
        id: 'channel2',
        title: 'Test Channel 2',
        slug: 'test-channel-2',
        created: DateTime(2025, 1, 3),
        playlists: <String>[],
      ),
      url: 'https://test.com',
    ),
  ];

  final testPlaylists = [
    PlaylistReference(
      playlist: DP1Call(
        dpVersion: '1.0.0',
        id: 'playlist1',
        slug: 'test-playlist-1',
        title: 'Test Playlist 1',
        created: DateTime(2025, 1, 1),
        items: <DP1Item>[],
        signature: '0x123',
      ),
      url: 'https://test.com',
    ),
    PlaylistReference(
      playlist: DP1Call(
        dpVersion: '1.0.0',
        id: 'playlist2',
        slug: 'test-playlist-2',
        title: 'Test Playlist 2',
        created: DateTime(2025, 1, 3),
        items: <DP1Item>[],
        signature: '0x456',
      ),
      url: 'https://test.com',
    ),
  ];

  setUp(() {
    mockFeedManager = MockFeralFileFeedManager();
    mockFeedService = MockBaseDP1FeedService();

    // Setup injector
    final getIt = GetIt.instance;
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }
    getIt.registerSingleton<FeralFileFeedManager>(mockFeedManager);

    // Default mock responses
    when(() => mockFeedManager.getAllCachedChannels())
        .thenAnswer((_) async => testChannels);
    when(() => mockFeedManager.getAllCachedPlaylists())
        .thenAnswer((_) async => testPlaylists);

    // Mock getFeedServiceByUrl - required for rendering playlists in UI
    when(() => mockFeedManager.getFeedServiceByUrl(any()))
        .thenReturn(mockFeedService);

    // Create blocs
    channelsBloc = ChannelsBloc();
    playlistsBloc = PlaylistsBloc();
  });

  tearDown(() {
    channelsBloc.close();
    playlistsBloc.close();

    final getIt = GetIt.instance;
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<ChannelsBloc>.value(value: channelsBloc),
            BlocProvider<PlaylistsBloc>.value(value: playlistsBloc),
          ],
          child: const ListDirectoryPage(),
        ),
      ),
    );
  }

  group('MobileController Home Integration Tests', () {
    testWidgets('should render home page with header tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Verify the page is rendered
      expect(find.byType(ListDirectoryPage), findsOneWidget);

      // Verify header tabs are present
      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Works'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);

      // Verify HeaderWidget is displayed
      expect(find.byType(HeaderWidget), findsOneWidget);
    });

    testWidgets('should load playlists and channels on initialization',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Verify playlists loaded on init
      verify(() => mockFeedManager.getAllCachedPlaylists()).called(1);

      // Switch to channels tab
      await tester.tap(find.text('Channels'));
      await tester.pumpAndSettle();

      // Now channels should be loaded
      verify(() => mockFeedManager.getAllCachedChannels()).called(1);
    });

    testWidgets('should display playlists when loaded successfully',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Wait for the async operation to complete
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });

      // Rebuild with the new state
      await tester.pumpAndSettle();

      // Verify playlists are displayed
      expect(find.text('Test Playlist 1'), findsOneWidget);
      expect(find.text('Test Playlist 2'), findsOneWidget);
    });

    testWidgets('should switch to channels tab and display channels',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Just render once

      // Tap on Channels tab (button should be visible regardless of data loading)
      await tester.tap(find.text('Channels'));
      await tester.pump();

      // Wait for channels to load
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify channels are displayed
      expect(find.text('Test Channel 1'), findsOneWidget);
      expect(find.text('Test Channel 2'), findsOneWidget);
    });

    testWidgets('should switch between tabs correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Wait for playlists to load
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify initial tab (Playlists)
      expect(find.text('Test Playlist 1'), findsOneWidget);

      // Switch to Channels
      await tester.tap(find.text('Channels'));
      await tester.pump();

      // Wait for channels to load
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Test Channel 1'), findsOneWidget);

      // Switch back to Playlists (data should still be there)
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      expect(find.text('Test Playlist 1'), findsOneWidget);

      // Switch to Channels again (data should still be there)
      await tester.tap(find.text('Channels'));
      await tester.pumpAndSettle();
      expect(find.text('Test Channel 1'), findsOneWidget);
    });

    testWidgets('should handle error state for playlists',
        (WidgetTester tester) async {
      // Setup error response
      when(() => mockFeedManager.getAllCachedPlaylists())
          .thenThrow(Exception('Failed to load playlists'));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Initial build
      await tester.pump(); // Loading state
      await tester.pump(); // Error state

      // Verify error state in bloc
      expect(playlistsBloc.state.isError, isTrue);
      expect(playlistsBloc.state.error, contains('Failed to load playlists'));
    });

    testWidgets('should handle error state for channels',
        (WidgetTester tester) async {
      // Setup error response for channels
      when(() => mockFeedManager.getAllCachedChannels())
          .thenThrow(Exception('Failed to load channels'));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Initial build

      // Trigger channels loading by switching to Channels tab
      await tester.tap(find.text('Channels'));
      await tester.pump(); // Loading state
      await tester.pump(); // Error state

      // Verify error state in bloc
      expect(channelsBloc.state.isError, isTrue);
      expect(channelsBloc.state.error, contains('Failed to load channels'));
    });

    testWidgets('should handle empty playlists state',
        (WidgetTester tester) async {
      // Setup empty response
      when(() => mockFeedManager.getAllCachedPlaylists())
          .thenAnswer((_) async => <PlaylistReference>[]);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Verify no playlists are displayed
      expect(find.text('Test Playlist 1'), findsNothing);
      expect(find.text('Test Playlist 2'), findsNothing);

      // Verify bloc state
      expect(playlistsBloc.state.playlists.length, equals(0));
    });

    testWidgets('should handle empty channels state',
        (WidgetTester tester) async {
      // Setup empty response for channels
      when(() => mockFeedManager.getAllCachedChannels())
          .thenAnswer((_) async => <ChannelReference>[]);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Switch to Channels tab
      await tester.tap(find.text('Channels'));
      await tester.pumpAndSettle();

      // Verify no channels are displayed
      expect(find.text('Test Channel 1'), findsNothing);
      expect(find.text('Test Channel 2'), findsNothing);

      // Verify bloc state
      expect(channelsBloc.state.channelReferences.length, equals(0));
    });

    testWidgets('should show loading indicator when playlists are loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Initial build

      // Verify loading state
      expect(playlistsBloc.state.isLoading, isTrue);

      // Wait for the async operation to complete
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });

      await tester.pumpAndSettle();

      // Verify loaded state
      expect(playlistsBloc.state.isLoaded, isTrue);
    });

    testWidgets('should show loading indicator when channels are loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Initial build

      // Switch to Channels tab to trigger initialization
      await tester.tap(find.text('Channels'));
      await tester.pump(); // Trigger the tab switch

      // Verify loading state
      expect(channelsBloc.state.isLoading, isTrue);

      // Wait for the async operation to complete
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });

      await tester.pumpAndSettle();

      // Verify loaded state
      expect(channelsBloc.state.isLoaded, isTrue);
    });

    testWidgets('should maintain state when switching tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Wait for playlists to load
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify playlists are loaded
      expect(find.text('Test Playlist 1'), findsOneWidget);

      // Switch to Channels
      await tester.tap(find.text('Channels'));
      await tester.pump();

      // Wait for channels to load
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Test Channel 1'), findsOneWidget);

      // Switch back to Playlists
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();

      // Verify playlists are still loaded (no reload)
      expect(find.text('Test Playlist 1'), findsOneWidget);

      // Verify getAllCachedPlaylists was only called once during initialization
      verify(() => mockFeedManager.getAllCachedPlaylists()).called(1);
    });

    testWidgets('should display correct number of playlists',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Wait for playlists to load
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify the bloc has correct number of playlists
      expect(playlistsBloc.state.playlists.length, equals(2));
    });

    testWidgets('should display correct number of channels',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap on Channels tab (button should be visible regardless of data loading)
      await tester.tap(find.text('Channels'));
      await tester.pump();

      // Wait for channels to load
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify the bloc has correct number of channels
      expect(channelsBloc.state.channelReferences.length, equals(2));
    });

    testWidgets('should handle state transitions from loading to loaded',
        (WidgetTester tester) async {
      // Check initial state before building
      expect(playlistsBloc.state.status, equals(PlaylistsStateStatus.initial));
      expect(channelsBloc.state.status, equals(ChannelsStateStatus.initial));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Trigger loading

      // Loading state
      expect(playlistsBloc.state.status, equals(PlaylistsStateStatus.loading));

      // Wait for the async operation to complete
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });

      // Loaded state
      expect(playlistsBloc.state.status, equals(PlaylistsStateStatus.loaded));

      // Switch to Channels
      await tester.tap(find.text('Channels'));
      await tester.pump();

      expect(channelsBloc.state.status, equals(ChannelsStateStatus.loading));

      // Wait for channels to load
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });

      // Loaded state
      expect(channelsBloc.state.status, equals(ChannelsStateStatus.loaded));
    });

    testWidgets('should handle state transitions from loading to error',
        (WidgetTester tester) async {
      // Setup error responses
      when(() => mockFeedManager.getAllCachedPlaylists())
          .thenThrow(Exception('Network error'));
      when(() => mockFeedManager.getAllCachedChannels())
          .thenThrow(Exception('Network error'));

      // Check initial state before building
      expect(playlistsBloc.state.status, equals(PlaylistsStateStatus.initial));
      expect(channelsBloc.state.status, equals(ChannelsStateStatus.initial));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump(); // Initial build
      await tester.pump(); // Allow state transitions to complete

      // Verify playlists ended in error state
      expect(playlistsBloc.state.status, equals(PlaylistsStateStatus.error));
      expect(playlistsBloc.state.error, contains('Network error'));

      // Switch to Channels tab to trigger its loading
      await tester.tap(find.text('Channels'));
      await tester.pump(); // Trigger tab switch
      await tester.pump(); // Allow channel loading and error

      // Verify channels ended in error state
      expect(channelsBloc.state.status, equals(ChannelsStateStatus.error));
      expect(channelsBloc.state.error, contains('Network error'));
    });

    testWidgets('should handle playlists with multiple items',
        (WidgetTester tester) async {
      // Setup response with more playlists
      final manyPlaylists = List.generate(
        10,
        (index) => PlaylistReference(
          playlist: DP1Call(
            dpVersion: '1.0.0',
            id: 'playlist$index',
            slug: 'test-playlist-$index',
            title: 'Test Playlist $index',
            created: DateTime(2025, 1, index + 1),
            items: <DP1Item>[],
            signature: '0x$index',
          ),
          url: 'https://test.com',
        ),
      );

      when(() => mockFeedManager.getAllCachedPlaylists())
          .thenAnswer((_) async => manyPlaylists);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Wait for playlists to load
      await tester.runAsync(() async {
        await playlistsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify the bloc has correct number of playlists
      expect(playlistsBloc.state.playlists.length, equals(10));
    });

    testWidgets('should handle channels with multiple items',
        (WidgetTester tester) async {
      // Setup response with more channels
      final manyChannels = List.generate(
        10,
        (index) => ChannelReference(
          channel: Channel(
            id: 'channel$index',
            title: 'Test Channel $index',
            slug: 'test-channel-$index',
            created: DateTime(2025, 1, index + 1),
            playlists: <String>[],
          ),
          url: 'https://test.com',
        ),
      );

      when(() => mockFeedManager.getAllCachedChannels())
          .thenAnswer((_) async => manyChannels);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap on Channels tab (button should be visible regardless of data loading)
      await tester.tap(find.text('Channels'));
      await tester.pump();

      // Wait for channels to load
      await tester.runAsync(() async {
        await channelsBloc.stream.firstWhere(
          (state) => state.isLoaded || state.isError,
        );
      });
      await tester.pumpAndSettle();

      // Verify the bloc has correct number of channels
      expect(channelsBloc.state.channelReferences.length, equals(10));
    });

    testWidgets('should display all header buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Find all header buttons
      final playlistsButton = find.text('Playlists');
      final channelsButton = find.text('Channels');
      final worksButton = find.text('Works');
      final collectionButton = find.text('Collection');

      // Verify all buttons are present
      expect(playlistsButton, findsOneWidget);
      expect(channelsButton, findsOneWidget);
      expect(worksButton, findsOneWidget);
      expect(collectionButton, findsOneWidget);

      // Note: Only testing Playlists and Channels tabs in this test file
      // Works and Collection tabs require additional mocked services
    });
  });
}
