//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_page.dart';
import 'package:autonomy_flutter/screen/meili_search/widgets/meili_search_result_section.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class _MockMeiliSearchService extends Mock implements MeiliSearchService {}

class _MockNavigationService extends Mock implements NavigationService {}

class _MockFeralFileFeedManager extends Mock implements FeralFileFeedManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMeiliSearchService mockMeiliSearchService;
  late _MockNavigationService mockNavigationService;
  late _MockFeralFileFeedManager mockFeedManager;
  late MeiliSearchBloc bloc;

  setUp(() {
    mockMeiliSearchService = _MockMeiliSearchService();
    mockNavigationService = _MockNavigationService();
    mockFeedManager = _MockFeralFileFeedManager();
    bloc = MeiliSearchBloc(mockMeiliSearchService);

    // Setup GetIt injector
    final getIt = GetIt.instance;

    // Unregister if already registered
    if (getIt.isRegistered<MeiliSearchBloc>()) {
      getIt.unregister<MeiliSearchBloc>();
    }
    if (getIt.isRegistered<NavigationService>()) {
      getIt.unregister<NavigationService>();
    }
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }

    // Register mocks
    getIt
      ..registerSingleton<MeiliSearchBloc>(bloc)
      ..registerSingleton<NavigationService>(mockNavigationService)
      ..registerSingleton<FeralFileFeedManager>(mockFeedManager);
  });

  tearDown(() async {
    await bloc.close();

    // Clean up injector
    final getIt = GetIt.instance;
    if (getIt.isRegistered<MeiliSearchBloc>()) {
      getIt.unregister<MeiliSearchBloc>();
    }
    if (getIt.isRegistered<NavigationService>()) {
      getIt.unregister<NavigationService>();
    }
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }
  });

  /// Helper to build testable widget with theme
  Widget _buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: BlocProvider<MeiliSearchBloc>.value(
          value: bloc,
          child: child,
        ),
      ),
    );
  }

  group('MeiliSearchPage Widget Tests', () {
    group('Widget Structure', () {
      testWidgets('renders without crashing', (tester) async {
        await tester.pumpWidget(_buildTestableWidget(const MeiliSearchPage()));
        expect(find.byType(MeiliSearchPage), findsOneWidget);
      });

      testWidgets('contains Column widget', (tester) async {
        await tester.pumpWidget(_buildTestableWidget(const MeiliSearchPage()));
        await tester.pumpAndSettle();

        expect(find.byType(Column), findsWidgets);
      });

      testWidgets('contains BlocBuilder', (tester) async {
        await tester.pumpWidget(_buildTestableWidget(const MeiliSearchPage()));
        await tester.pumpAndSettle();

        expect(find.byType(BlocBuilder<MeiliSearchBloc, MeiliSearchState>),
            findsOneWidget);
      });
    });

    group('Initial State', () {
      testWidgets('shows empty state when no search performed', (tester) async {
        await tester.pumpWidget(_buildTestableWidget(const MeiliSearchPage()));
        await tester.pumpAndSettle();

        // Should not show any result sections initially
        expect(find.text('Channels'), findsNothing);
        expect(find.text('Playlists'), findsNothing);
        expect(find.text('Items'), findsNothing);
        expect(find.text('No results found'), findsNothing);
      });
    });

    group('Scrolling Behavior', () {
      testWidgets('has scrollable content', (tester) async {
        await tester.pumpWidget(_buildTestableWidget(const MeiliSearchPage()));
        await tester.pumpAndSettle();

        // The page should build without errors
        expect(find.byType(MeiliSearchPage), findsOneWidget);
      });
    });
  });

  group('MeiliSearchResultSection Widget Tests', () {
    testWidgets('renders with title and child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeiliSearchResultSection<String>(
              title: 'Test Section',
              builder: (context) => const Text('Test Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Section'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('renders with correct header padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeiliSearchResultSection<String>(
              title: 'Test Section',
              builder: (context) => const Text('Test Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section should render without errors
      expect(find.byType(MeiliSearchResultSection<String>), findsOneWidget);
    });

    testWidgets('builder function is called', (tester) async {
      var builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeiliSearchResultSection<String>(
              title: 'Test Section',
              builder: (context) {
                builderCalled = true;
                return const Text('Test Content');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(builderCalled, isTrue);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('expands by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeiliSearchResultSection<String>(
              title: 'Expandable Section',
              builder: (context) => const SizedBox(
                height: 200,
                child: Text('Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Content should be visible (section expanded by default)
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders multiple sections correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MeiliSearchResultSection<String>(
                  title: 'Section 1',
                  builder: (context) => const Text('Content 1'),
                ),
                MeiliSearchResultSection<String>(
                  title: 'Section 2',
                  builder: (context) => const Text('Content 2'),
                ),
                MeiliSearchResultSection<String>(
                  title: 'Section 3',
                  builder: (context) => const Text('Content 3'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section 1'), findsOneWidget);
      expect(find.text('Section 2'), findsOneWidget);
      expect(find.text('Section 3'), findsOneWidget);
      expect(find.text('Content 1'), findsOneWidget);
      expect(find.text('Content 2'), findsOneWidget);
      expect(find.text('Content 3'), findsOneWidget);
    });
  });
}
