import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_object/address_cloud_object.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_object/dp1_feed_cloud_object.dart';
import 'package:autonomy_flutter/model/error/dp1_error.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry/sentry.dart';

// Mock classes
class MockFeralFileDP1FeedService extends Mock
    implements FeralFileDP1FeedService {}

class MockCloudManager extends Mock implements CloudManager {}

class MockDP1FeedCloudObject extends Mock implements DP1FeedCloudObject {}

class MockWalletAddressCloudObject extends Mock
    implements WalletAddressCloudObject {}

class MockConfigurationService extends Mock implements ConfigurationService {}

class MockUserAllOwnCollectionBloc extends Mock
    implements UserAllOwnCollectionBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserDp1PlaylistService service;
  late MockFeralFileDP1FeedService mockDP1FeedService;
  late MockCloudManager mockCloudManager;
  late MockDP1FeedCloudObject mockDP1FeedCloudObject;
  late MockWalletAddressCloudObject mockAddressObject;
  late MockConfigurationService mockConfigurationService;
  late MockUserAllOwnCollectionBloc mockUserAllOwnCollectionBloc;

  // Test data
  const testPlaylistId = 'test-playlist-id';
  final testAddresses = ['address1', 'address2', 'address3'];
  final testDateTime = DateTime(2025, 1, 1);

  DP1Call createTestPlaylist({
    String? id,
    String? title,
    List<String>? owners,
    List<DP1Item>? items,
  }) {
    return DP1Call(
      dpVersion: '1.0.0',
      id: id ?? testPlaylistId,
      slug: 'test-slug',
      title: title ?? 'Test Playlist',
      created: testDateTime,
      items: items ?? [],
      signature: 'test-signature',
      dynamicQueries: [
        DynamicQuery(
          endpoint: 'https://test.com/graphql',
          params: DynamicQueryParams(
            owners: owners ?? testAddresses,
          ),
        ),
      ],
    );
  }

  List<WalletAddress> createTestWalletAddresses() {
    return [
      WalletAddress(
        address: 'address1',
        createdAt: testDateTime,
        isHidden: false,
      ),
      WalletAddress(
        address: 'address2',
        createdAt: testDateTime,
        isHidden: false,
      ),
      WalletAddress(
        address: 'address3',
        createdAt: testDateTime,
        isHidden: false,
      ),
    ];
  }

  setUpAll(() async {
    // Load environment variables
    dotenv.testLoad(fileInput: '''
INDEXER_URL=https://test-indexer.example.com
''');

    // Register fallback values for mocktail
    registerFallbackValue(
      DP1CreatePlaylistRequest(
        dpVersion: '',
        title: '',
        items: [],
      ),
    );
    registerFallbackValue(
      UpdateDynamicQueryEvent(
        dynamicQuery: DynamicQuery(
          endpoint: 'test',
          params: DynamicQueryParams(owners: []),
        ),
      ),
    );
  });

  setUp(() {
    // Setup mocks
    mockDP1FeedService = MockFeralFileDP1FeedService();
    mockCloudManager = MockCloudManager();
    mockDP1FeedCloudObject = MockDP1FeedCloudObject();
    mockAddressObject = MockWalletAddressCloudObject();
    mockConfigurationService = MockConfigurationService();
    mockUserAllOwnCollectionBloc = MockUserAllOwnCollectionBloc();

    // Setup injector
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ConfigurationService>()) {
      getIt.unregister<ConfigurationService>();
    }
    if (getIt.isRegistered<UserAllOwnCollectionBloc>()) {
      getIt.unregister<UserAllOwnCollectionBloc>();
    }
    getIt
      ..registerSingleton<ConfigurationService>(mockConfigurationService)
      ..registerSingleton<UserAllOwnCollectionBloc>(
        mockUserAllOwnCollectionBloc,
      );

    // Setup cloud manager
    when(() => mockCloudManager.dp1FeedCloudObject)
        .thenReturn(mockDP1FeedCloudObject);
    when(() => mockCloudManager.addressObject).thenReturn(mockAddressObject);

    // Setup default responses
    when(() => mockConfigurationService.getAddressLastRefreshedTime())
        .thenReturn({});
    when(() => mockConfigurationService.setAddressLastRefreshedTime(any()))
        .thenAnswer((_) async => {});
    when(() => mockConfigurationService.clearAddressLastRefreshedTime())
        .thenAnswer((_) async => {});

    // Setup UserAllOwnCollectionBloc mock
    when(() => mockUserAllOwnCollectionBloc.add(any())).thenReturn(null);

    // Create service
    service = UserDp1PlaylistService(mockDP1FeedService, mockCloudManager);
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ConfigurationService>()) {
      getIt.unregister<ConfigurationService>();
    }
    if (getIt.isRegistered<UserAllOwnCollectionBloc>()) {
      getIt.unregister<UserAllOwnCollectionBloc>();
    }
  });

  group('UserDp1PlaylistService - allOwnedPlaylist', () {
    test('should return playlist when owned playlist exists', () async {
      // Arrange
      final testPlaylist = createTestPlaylist();
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => testPlaylist);

      // Act
      final result = await service.allOwnedPlaylist();

      // Assert
      expect(result, equals(testPlaylist));
      verify(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).called(1);
      verify(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .called(1);
    });

    test('should throw error when owned playlist IDs are empty', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).thenReturn([]);

      // Act & Assert
      expect(
        () => service.allOwnedPlaylist(),
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });

    test('should throw error when playlist not found in DP1 service', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.allOwnedPlaylist(),
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });
  });

  group('UserDp1PlaylistService - createAllOwnedPlaylistIfNotExists', () {
    test('should return existing playlist if it exists', () async {
      // Arrange
      final testPlaylist = createTestPlaylist();
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(
        () => mockDP1FeedService.getPlaylistById(
          testPlaylistId,
          usingCache: false,
        ),
      ).thenAnswer((_) async => testPlaylist);

      // Act
      final result = await service.createAllOwnedPlaylistIfNotExists();

      // Assert
      expect(result, equals(testPlaylist));
      expect(service.cachedAllOwnedPlaylist, equals(testPlaylist));
      verify(
        () => mockDP1FeedService.getPlaylistById(
          testPlaylistId,
          usingCache: false,
        ),
      ).called(1);
      verifyNever(() => mockDP1FeedService.createPlaylist(
          request: any(named: 'request'),
          isSyncToCloud: any(named: 'isSyncToCloud')));
    });

    test('should create new playlist if owned playlist IDs are empty',
        () async {
      // Arrange
      final testAddresses = createTestWalletAddresses();
      final createdPlaylist = createTestPlaylist();

      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).thenReturn([]);
      when(() => mockAddressObject.getAllAddresses()).thenReturn(testAddresses);
      when(() => mockDP1FeedService.createPlaylist(
            request: any(named: 'request'),
            isSyncToCloud: true,
          )).thenAnswer((_) async => createdPlaylist);
      when(() => mockDP1FeedCloudObject.addOwnedPlaylistId(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await service.createAllOwnedPlaylistIfNotExists();

      // Assert
      expect(result, equals(createdPlaylist));
      expect(service.cachedAllOwnedPlaylist, equals(createdPlaylist));
      verify(
        () => mockDP1FeedService.createPlaylist(
          request: any(named: 'request'),
          isSyncToCloud: true,
        ),
      ).called(1);
      verify(() =>
              mockDP1FeedCloudObject.addOwnedPlaylistId(createdPlaylist.id))
          .called(1);
    });

    test(
        'should remove invalid playlist ID and create new one if playlist not found',
        () async {
      // Arrange
      final testAddresses = createTestWalletAddresses();
      final createdPlaylist = createTestPlaylist();

      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId,
          usingCache: false)).thenAnswer((_) async => null);
      when(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(testPlaylistId))
          .thenAnswer((_) async => {});
      when(() => mockAddressObject.getAllAddresses()).thenReturn(testAddresses);
      when(() => mockDP1FeedService.createPlaylist(
            request: any(named: 'request'),
            isSyncToCloud: true,
          )).thenAnswer((_) async => createdPlaylist);
      when(() => mockDP1FeedCloudObject.addOwnedPlaylistId(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await service.createAllOwnedPlaylistIfNotExists();

      // Assert
      expect(result, equals(createdPlaylist));
      expect(service.cachedAllOwnedPlaylist, equals(createdPlaylist));
      verify(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(testPlaylistId))
          .called(1);
      verify(() => mockDP1FeedService.createPlaylist(
            request: any(named: 'request'),
            isSyncToCloud: true,
          )).called(1);
      verify(() =>
              mockDP1FeedCloudObject.addOwnedPlaylistId(createdPlaylist.id))
          .called(1);
    });

    test('should filter out hidden addresses when creating playlist', () async {
      // Arrange
      final testAddresses = [
        WalletAddress(
          address: 'address1',
          createdAt: testDateTime,
          isHidden: false,
        ),
        WalletAddress(
          address: 'address2',
          createdAt: testDateTime,
          isHidden: true, // This should be filtered out
        ),
        WalletAddress(
          address: 'address3',
          createdAt: testDateTime,
          isHidden: false,
        ),
      ];
      final createdPlaylist = createTestPlaylist();

      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).thenReturn([]);
      when(() => mockAddressObject.getAllAddresses()).thenReturn(testAddresses);
      when(() => mockDP1FeedService.createPlaylist(
            request: any(named: 'request'),
            isSyncToCloud: true,
          )).thenAnswer((_) async => createdPlaylist);
      when(() => mockDP1FeedCloudObject.addOwnedPlaylistId(any()))
          .thenAnswer((_) async => {});

      // Act
      await service.createAllOwnedPlaylistIfNotExists();

      // Assert
      final captured = verify(() => mockDP1FeedService.createPlaylist(
            request: captureAny(named: 'request'),
            isSyncToCloud: true,
          )).captured;
      final request = captured.first as DP1CreatePlaylistRequest;
      expect(request.dynamicQueries, isNotNull);
      expect(request.dynamicQueries!.isNotEmpty, isTrue);
      final owners = request.dynamicQueries![0].params.owners;
      expect(owners.length, equals(2));
      expect(owners.contains('address1'), isTrue);
      expect(owners.contains('address2'), isFalse);
      expect(owners.contains('address3'), isTrue);
    });
  });

  group('UserDp1PlaylistService - getPlaylistById', () {
    test('should return playlist when found', () async {
      // Arrange
      final testPlaylist = createTestPlaylist();
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => testPlaylist);

      // Act
      final result = await service.getPlaylistById(testPlaylistId);

      // Assert
      expect(result, equals(testPlaylist));
      verify(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .called(1);
    });

    test('should return null when playlist not found', () async {
      // Arrange
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => null);

      // Act
      final result = await service.getPlaylistById(testPlaylistId);

      // Assert
      expect(result, isNull);
    });
  });

  group('UserDp1PlaylistService - insertAddressesToPlaylist', () {
    test('should insert addresses to playlist successfully', () async {
      // Arrange
      final currentPlaylist = createTestPlaylist(owners: ['address1']);
      final updatedPlaylist =
          createTestPlaylist(owners: ['address1', 'address2', 'address3']);
      final addressesToInsert = ['address2', 'address3'];

      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => currentPlaylist);
      when(() => mockDP1FeedService.updatePlaylist(
            playlistId: testPlaylistId,
            request: any(named: 'request'),
          )).thenAnswer((_) async => updatedPlaylist);

      // Act
      final result = await service.insertAddressesToPlaylist(addressesToInsert);

      // Assert
      expect(result, equals(updatedPlaylist));
      expect(service.cachedAllOwnedPlaylist, equals(updatedPlaylist));
      verify(() => mockDP1FeedService.updatePlaylist(
            playlistId: testPlaylistId,
            request: any(named: 'request'),
          )).called(1);
    });

    test('should throw error when owned playlist IDs are empty', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).thenReturn([]);

      // Act & Assert
      expect(
        () => service.insertAddressesToPlaylist(['address1']),
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });

    test('should throw error when playlist not found', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.insertAddressesToPlaylist(['address1']),
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });
  });

  group('UserDp1PlaylistService - removeAddressesFromPlaylist', () {
    test('should remove addresses from playlist successfully', () async {
      // Arrange
      final currentPlaylist =
          createTestPlaylist(owners: ['address1', 'address2', 'address3']);
      final updatedPlaylist = createTestPlaylist(owners: ['address1']);
      final addressesToRemove = ['address2', 'address3'];

      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => currentPlaylist);
      when(() => mockDP1FeedService.updatePlaylist(
            playlistId: testPlaylistId,
            request: any(named: 'request'),
          )).thenAnswer((_) async => updatedPlaylist);

      // Act
      final result =
          await service.removeAddressesFromPlaylist(addressesToRemove);

      // Assert
      expect(result, equals(updatedPlaylist));
      expect(service.cachedAllOwnedPlaylist, equals(updatedPlaylist));
      verify(() => mockDP1FeedService.updatePlaylist(
            playlistId: testPlaylistId,
            request: any(named: 'request'),
          )).called(1);
    });

    test('should throw error when owned playlist IDs are empty', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).thenReturn([]);

      // Act & Assert
      expect(
        () => service.removeAddressesFromPlaylist(['address1']),
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });

    test('should throw error when playlist not found', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn([testPlaylistId]);
      when(() => mockDP1FeedService.getPlaylistById(testPlaylistId))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => service.removeAddressesFromPlaylist(['address1']),
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });
  });

  group('UserDp1PlaylistService - deleteAllPlaylists', () {
    test('should delete all playlists successfully', () async {
      // Arrange
      final playlistIds = ['playlist1', 'playlist2', 'playlist3'];
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn(playlistIds);
      when(() => mockDP1FeedService.deletePlaylist(any()))
          .thenAnswer((_) async => true);
      when(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(any()))
          .thenAnswer((_) async => {});
      when(() => mockConfigurationService.setAddressLastRefreshedTime(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await service.deleteAllPlaylists();

      // Assert
      expect(result, isTrue);
      verify(() => mockDP1FeedService.deletePlaylist('playlist1')).called(1);
      verify(() => mockDP1FeedService.deletePlaylist('playlist2')).called(1);
      verify(() => mockDP1FeedService.deletePlaylist('playlist3')).called(1);
      verify(() => mockConfigurationService.setAddressLastRefreshedTime({}))
          .called(1);
    });

    test('should return true when owned playlist IDs are empty', () async {
      // Arrange
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds()).thenReturn([]);

      // Act
      final result = await service.deleteAllPlaylists();

      // Assert
      expect(result, isTrue);
      verifyNever(() => mockDP1FeedService.deletePlaylist(any()));
    });

    test('should return false if any deletion fails', () async {
      // Arrange
      final playlistIds = ['playlist1', 'playlist2'];
      when(() => mockDP1FeedCloudObject.getOwnedPlaylistIds())
          .thenReturn(playlistIds);
      when(() => mockDP1FeedService.deletePlaylist('playlist1'))
          .thenAnswer((_) async => true);
      when(() => mockDP1FeedService.deletePlaylist('playlist2'))
          .thenAnswer((_) async => false);
      when(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(any()))
          .thenAnswer((_) async => {});
      when(() => mockConfigurationService.setAddressLastRefreshedTime(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await service.deleteAllPlaylists();

      // Assert
      expect(result, isFalse);
    });
  });

  group('UserDp1PlaylistService - deletePlaylist', () {
    test('should delete playlist successfully', () async {
      // Arrange
      when(() => mockDP1FeedService.deletePlaylist(testPlaylistId))
          .thenAnswer((_) async => true);
      when(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(testPlaylistId))
          .thenAnswer((_) async => {});

      // Act
      final result = await service.deletePlaylist(testPlaylistId);

      // Assert
      expect(result, isTrue);
      verify(() => mockDP1FeedService.deletePlaylist(testPlaylistId)).called(1);
      verify(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(testPlaylistId))
          .called(1);
    });

    test('should return false when deletion fails', () async {
      // Arrange
      when(() => mockDP1FeedService.deletePlaylist(testPlaylistId))
          .thenThrow(Exception('Delete failed'));
      when(() => mockDP1FeedCloudObject.removeOwnedPlaylistId(testPlaylistId))
          .thenAnswer((_) async => {});

      // Act
      final result = await service.deletePlaylist(testPlaylistId);

      // Assert
      expect(result, isFalse);
    });
  });

  group('UserDp1PlaylistService - updateAddressLastRefreshedTime', () {
    test('should update address last refreshed time with provided DateTime',
        () async {
      // Arrange
      final addresses = ['address1', 'address2'];
      final dateTime = DateTime(2025, 1, 15);
      final existingTimes = {'address3': DateTime(2025, 1, 1)};
      when(() => mockConfigurationService.getAddressLastRefreshedTime())
          .thenReturn(existingTimes);
      when(() => mockConfigurationService.setAddressLastRefreshedTime(any()))
          .thenAnswer((_) async => {});

      // Act
      await service.updateAddressLastRefreshedTime(
        addresses: addresses,
        dateTime: dateTime,
      );

      // Assert
      final captured = verify(() => mockConfigurationService
          .setAddressLastRefreshedTime(captureAny())).captured;
      final updatedTimes = captured.first as Map<String, DateTime>;
      expect(updatedTimes['address1'], equals(dateTime));
      expect(updatedTimes['address2'], equals(dateTime));
      expect(updatedTimes['address3'], equals(DateTime(2025, 1, 1)));
    });

    test('should update address last refreshed time with current DateTime',
        () async {
      // Arrange
      final addresses = ['address1'];
      when(() => mockConfigurationService.getAddressLastRefreshedTime())
          .thenReturn({});
      when(() => mockConfigurationService.setAddressLastRefreshedTime(any()))
          .thenAnswer((_) async => {});

      // Act
      await service.updateAddressLastRefreshedTime(addresses: addresses);

      // Assert
      final captured = verify(() => mockConfigurationService
          .setAddressLastRefreshedTime(captureAny())).captured;
      final updatedTimes = captured.first as Map<String, DateTime>;
      expect(updatedTimes['address1'], isNotNull);
      expect(updatedTimes['address1']!.isBefore(DateTime.now()), isTrue);
    });
  });

  group('UserDp1PlaylistService - getAddressOldestLastRefreshedTime', () {
    test('should return oldest time for given addresses', () {
      // Arrange
      final addresses = ['address1', 'address2', 'address3'];
      final times = {
        'address1': DateTime(2025, 1, 10),
        'address2': DateTime(2025, 1, 5), // Oldest
        'address3': DateTime(2025, 1, 15),
      };
      when(() => mockConfigurationService.getAddressLastRefreshedTime())
          .thenReturn(times);

      // Act
      final result =
          service.getAddressOldestLastRefreshedTime(addresses: addresses);

      // Assert
      expect(result, equals(DateTime(2025, 1, 5)));
    });

    test('should return epoch time when addresses list is empty', () {
      // Act
      final result = service.getAddressOldestLastRefreshedTime(addresses: []);

      // Assert
      expect(result, equals(DateTime(1970, 1, 1)));
    });

    test('should return epoch time when any address is not in the map', () {
      // Arrange
      final addresses = ['address1', 'address2', 'address3'];
      final times = {
        'address1': DateTime(2025, 1, 10),
        'address2': DateTime(2025, 1, 5),
        // address3 is missing
      };
      when(() => mockConfigurationService.getAddressLastRefreshedTime())
          .thenReturn(times);

      // Act
      final result =
          service.getAddressOldestLastRefreshedTime(addresses: addresses);

      // Assert
      expect(result, equals(DateTime(1970, 1, 1)));
    });
  });

  group('UserDp1PlaylistService - clearData', () {
    test('should clear all data', () async {
      // Arrange
      final testPlaylist = createTestPlaylist();
      service.cachedAllOwnedPlaylist = testPlaylist;
      when(() => mockConfigurationService.clearAddressLastRefreshedTime())
          .thenAnswer((_) async => {});

      // Act
      await service.clearData();

      // Assert
      verify(() => mockConfigurationService.clearAddressLastRefreshedTime())
          .called(1);
      // Note: We cannot directly verify that cachedAllOwnedPlaylist is null
      // because accessing it when null throws an error
    });
  });

  group('UserDp1PlaylistService - cachedAllOwnedPlaylist', () {
    test('should throw error when accessing null cached playlist', () {
      // Act & Assert
      expect(
        () => service.cachedAllOwnedPlaylist,
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });

    test('should set and get cached playlist', () {
      // Arrange
      final testPlaylist = createTestPlaylist();

      // Act
      service.cachedAllOwnedPlaylist = testPlaylist;

      // Assert
      expect(service.cachedAllOwnedPlaylist, equals(testPlaylist));
    });

    test('should handle setting null cached playlist', () {
      // Arrange
      final testPlaylist = createTestPlaylist();
      service.cachedAllOwnedPlaylist = testPlaylist;

      // Act
      service.cachedAllOwnedPlaylist = null;

      // Assert
      expect(
        () => service.cachedAllOwnedPlaylist,
        throwsA(isA<DP1AllOwnCollectionEmptyError>()),
      );
    });
  });
}
