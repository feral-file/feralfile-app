import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:collection/collection.dart';

class FeedServerInfo {
  FeedServerInfo({required this.url, required this.createdAt});
  FeedServerInfo.fromUrl(String url)
      : url = url,
        createdAt = DateTime.now();
  final String url;
  final DateTime createdAt;
}

class FeedManager {
  factory FeedManager() {
    return instance;
  }
  FeedManager._() {}
  static final FeedManager instance = FeedManager._();
  final List<Pair<String, BaseDP1FeedServiceImpl>> _feedServices = [];

  FeralFileDP1FeedService get feralFileFeedService => _feedServices
      .firstWhere((feedService) => feedService.first == Environment.dp1FeedUrl)
      .second as FeralFileDP1FeedService;

  Future<void> init() async {}

  BaseDP1FeedServiceImpl addFeedService(BaseDP1FeedServiceImpl feedService) {
    if (isFeedServiceExists(feedService.baseUrl)) {
      log.info('Feed service already exists for url: ${feedService.baseUrl}');
      return getFeedServiceByUrl(feedService.baseUrl)!;
    }
    _feedServices.add(Pair(feedService.baseUrl, feedService));
    return feedService;
  }

  BaseDP1FeedServiceImpl? getFeedServiceByUrl(String url) {
    return _feedServices
        .firstWhereOrNull((feedService) => feedService.first == url)
        ?.second;
  }

  void removeFeedServiceByUrl(String url) {
    _feedServices.removeWhere((feedService) => feedService.first == url);
  }

  bool isFeedServiceExists(String url) {
    return _feedServices.any((feedService) => feedService.first == url);
  }

  List<BaseDP1FeedServiceImpl> get feedServices =>
      [..._feedServices.map((e) => e.second)];

  Future<void> reloadAllCache({
    bool force = false,
  }) async {
    // local cache last refresh time
    final lastTimeRefreshFeeds =
        injector<ConfigurationService>().getLastTimeRefreshFeeds() ??
            DateTime(1970, 1, 1);
    final updateFeedDurationString =
        injector<RemoteConfigService>().getConfig<String>(
      ConfigGroup.dp1Playlist,
      ConfigKey.dp1FeedCacheDuration,
      const Duration(days: 1).toString(),
    );
    final updateFeedDuration =
        Duration(seconds: int.parse(updateFeedDurationString));
    // remote config last update time
    final lastFeedUpdateAtString =
        injector<RemoteConfigService>().getConfig<String>(
      ConfigGroup.dp1Playlist,
      ConfigKey.dp1FeedLastUpdated,
      DateTime(2023, 1, 1).toString(),
    );
    final lastFeedUpdateAt = DateTime.parse(lastFeedUpdateAtString);
    // we should update the cache if more than updateFeedDuration or lastFeedUpdateAt is before now
    final shouldUpdate = lastTimeRefreshFeeds
            .isBefore(DateTime.now().subtract(updateFeedDuration)) ||
        lastFeedUpdateAt.isAfter(lastTimeRefreshFeeds);
    if (force || shouldUpdate) {
      for (final feedService in feedServices) {
        await feedService.reloadCache();
      }
      await injector<ConfigurationService>()
          .setLastTimeRefreshFeeds(DateTime.now());
      log.info(
          'Reload all cache, last time refresh feeds: $lastTimeRefreshFeeds, duration: $updateFeedDuration, force: $force');
      await Future.delayed(const Duration(milliseconds: 500));
      injector<ChannelsBloc>(
              instanceName: ChannelsBlocInstance.curated.instanceName)
          .add(const RefreshChannelsEvent());
      injector<PlaylistsBloc>(
              instanceName: PlaylistsBlocInstance.curated.instanceName)
          .add(RefreshPlaylistsEvent());
    } else {
      log.info(
          'Skip reload all cache, last time refresh feeds: $lastTimeRefreshFeeds, duration: $updateFeedDuration, force: $force');
    }
  }

  Future<List<PlaylistReference>> getAllCachedPlaylists() async {
    List<PlaylistReference> allPlaylists = [];
    for (final feedService in feedServices) {
      final playlists = await feedService.getAllCachedPlaylists();
      allPlaylists.addAll(playlists.map((item) =>
          PlaylistReference(playlist: item, url: feedService.baseUrl)));
    }
    return allPlaylists;
  }

  void clearAllCache() {
    for (final feedService in feedServices) {
      feedService.clearCache();
    }
  }
}

class FeralFileFeedManager extends FeedManager {
  factory FeralFileFeedManager() {
    return instance;
  }
  FeralFileFeedManager._() : super._();

  static final FeralFileFeedManager instance = FeralFileFeedManager._();

  @override
  Future<void> init() async {
    _setupDefault();
  }

  void _setupDefault() {}

  Future<void> setupRemoteConfigChannels(List<String> channelUrls) async {
    final remoteConfigChannels = channelUrls.map((url) {
      final uri = Uri.parse(url);
      return RemoteConfigChannel(
        endpoint: uri.origin,
        channelId: uri.pathSegments.last,
      );
    }).toList();
    this.remoteConfigChannels = remoteConfigChannels;
    final Map<String, List<String>> channelIdsByUrl = <String, List<String>>{};
    for (final channel in remoteConfigChannels) {
      if (channelIdsByUrl[channel.endpoint] == null) {
        channelIdsByUrl[channel.endpoint] = [];
      }
      channelIdsByUrl[channel.endpoint]!.add(channel.channelId);
    }

    for (final endpoint in channelIdsByUrl.keys) {
      final existingService = getFeedServiceByUrl(endpoint);
      if (existingService != null) {
        (existingService as FeralFileDP1FeedService)
            .addRemoteConfigChannelIds(channelIdsByUrl[endpoint]!);
        continue;
      } else {
        final service = FeralFileDP1FeedService(baseUrl: endpoint);
        dynamic error;
        await service.init(onPlaylistError: (e) {
          error = e;
        }, onChannelError: (e) {
          error = e;
        });

        service.addRemoteConfigChannelIds(channelIdsByUrl[endpoint]!);
        if (error is Object) {
          log.info('Error initializing feed service: $error');
          await service.reloadCache();
        }
        addFeedService(service);
      }
    }
    log.info(
        'Finish Setup remote config channels: ${remoteConfigChannels.map((e) => e.channelId).toList()}');

    final customFeedServers = injector<AppDataManager>()
        .dp1FeedStorageService
        .getCustomFeedServersByUrls();
    for (final customFeedServer in customFeedServers) {
      final service = BaseDP1FeedServiceImpl(
          baseUrl: customFeedServer, isExternalFeedService: true);
      dynamic error;
      await service.init(onPlaylistError: (e) {
        error = e;
      }, onChannelError: (e) {
        error = e;
      });
      if (error is Object) {
        log.info('Error initializing feed service: $error');
        await service.reloadCache();
      }
      addFeedService(service);
    }
  }

  List<RemoteConfigChannel> remoteConfigChannels = [];

  Future<void> addCustomFeedServices(
      List<BaseDP1FeedServiceImpl> services) async {
    for (final service in services) {
      try {
        if (isFeedServiceExists(service.baseUrl)) {
          log.info('Custom feed service already exists: ${service.baseUrl}');
          continue;
        }
        addFeedService(service);
        await injector<AppDataManager>()
            .dp1FeedStorageService
            .insertCustomFeedServersByUrls([service.baseUrl]);
        log.info('Added custom feed service: ${service.baseUrl}');
      } catch (e) {
        log.info('Error adding custom feed service: ${service.baseUrl}: $e');
      }
    }
  }

  Future<List<Channel>> fetchAllChannels() async {
    List<Channel> allChannels = [];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channels = await feedService.getChannels();
        allChannels.addAll(channels.items);
      }
    }
    return allChannels;
  }

  Future<List<ChannelReference>> getAllCachedChannels() async {
    List<ChannelReference> allChannelReferences = [];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channels = feedService.getAllCachedChannels();
        allChannelReferences.addAll(channels.map((item) =>
            ChannelReference(channel: item, url: feedService.baseUrl)));
      }
    }
    return allChannelReferences;
  }

  // get all cache playlists of channels
  List<PlaylistReference> getAllCachedPlaylistsOfChannels(
      List<ChannelReference> channels) {
    List<PlaylistReference> allPlaylistReferences = [];
    for (final channel in channels) {
      final service = getFeedServiceByUrl(channel.url);
      if (service is FeralFileDP1FeedService) {
        final playlists =
            service.getCachedPlaylistsByChannelId(channel.channel.id);
        allPlaylistReferences.addAll(playlists.map(
            (item) => PlaylistReference(playlist: item, url: channel.url)));
      }
    }
    return allPlaylistReferences;
  }

  Future<ChannelReference?> getChannelReferenceByChannelId(
      String channelId) async {
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        try {
          final channel = await feedService.getChannelDetail(channelId);
          if (channel != null) {
            return ChannelReference(channel: channel, url: feedService.baseUrl);
          }
        } catch (e) {
          log.info(
              'Error getting channel by ID $channelId: $e, service: ${feedService.baseUrl}');
        }
      }
    }
    return null;
  }

  Future<PlaylistReference?> getPlaylistReferenceByPlaylistId(
      String playlistId) async {
    for (final feedService in feedServices) {
      final playlist = await feedService.getPlaylistById(playlistId);
      if (playlist != null) {
        return PlaylistReference(playlist: playlist, url: feedService.baseUrl);
      }
    }
    return null;
  }

  Future<DP1PlaylistItemsResponse> getPlaylistItemsByListOfChannels({
    required List<RemoteConfigChannel> channels,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (channels.isEmpty) {
      return DP1PlaylistItemsResponse([], false, null);
    }

    // Parse cursor to get current channel index and channel cursor
    int currentChannelIndex = 0;
    String? currentChannelCursor = cursor;

    if (cursor != null && cursor.contains(':')) {
      final parts = cursor.split(':');
      if (parts.length == 2) {
        currentChannelIndex = int.tryParse(parts[0]) ?? 0;
        currentChannelCursor = parts[1].isEmpty ? null : parts[1];
      }
    }

    // Ensure index is within bounds
    currentChannelIndex = currentChannelIndex.clamp(0, channels.length - 1);

    final List<DP1Item> allItems = [];
    bool hasMore = false;
    String? nextCursor;

    // Start from current channel index
    for (int i = currentChannelIndex; i < channels.length; i++) {
      final channel = channels[i];
      try {
        // Calculate remaining limit for this channel
        final remainingLimit = limit != null ? limit - allItems.length : limit;

        final feedService =
            getFeedServiceByUrl(channel.endpoint) as FeralFileDP1FeedService;

        final response = await feedService.getPlaylistItemsOfChannel(
          channelId: channel.channelId,
          cursor: (i == currentChannelIndex) ? currentChannelCursor : null,
          limit: remainingLimit,
          usingCache: usingCache,
        );

        allItems.addAll(response.items);

        // Check if we've reached the limit after adding items
        if (limit != null && allItems.length >= limit) {
          if (response.hasMore) {
            // Current channel has more items, continue with this channel
            hasMore = true;
            nextCursor = '${i}:${response.cursor ?? ''}';
          } else if (i < channels.length - 1) {
            // Current channel is exhausted but there are more channels
            hasMore = true;
            nextCursor = '${i + 1}:';
          }
          break;
        }

        if (response.hasMore) {
          // If current channel has more items, continue with this channel
          hasMore = true;
          nextCursor = '${i}:${response.cursor ?? ''}';
          break;
        } else if (i < channels.length - 1) {
          // If current channel is exhausted but there are more channels, continue to next
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      } catch (e) {
        log.info(
            'Error getting playlist items for channel ${channel.channelId}: $e');
        // Continue to next channel on error
        if (i < channels.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      }
    }

    return DP1PlaylistItemsResponse(
      allItems,
      hasMore,
      nextCursor,
    );
  }

  ChannelReference? getCachedChannelReferenceByPlaylist(DP1Call playlist) {
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channel = feedService.getChannelByPlaylistId(playlist.id);
        if (channel != null) {
          return ChannelReference(channel: channel, url: feedService.baseUrl);
        }
      }
    }
    return null;
  }
}

enum PlaylistReferenceType {
  channel,
  address,
}

class PlaylistReference {
  factory PlaylistReference.fromFeralFileDP1Call(DP1Call dp1Call) =>
      PlaylistReference(
          playlist: dp1Call,
          url: Environment.dp1FeedUrl,
          type: PlaylistReferenceType.channel);

  PlaylistReference(
      {required this.playlist,
      required this.url,
      this.type = PlaylistReferenceType.channel});

  final DP1Call playlist;
  final String url;
  final PlaylistReferenceType type;

  bool get isExternalFeedService =>
      injector<FeralFileFeedManager>()
          .getFeedServiceByUrl(url)
          ?.isExternalFeedService ??
      false;

  String? get fullUrl {
    final origin = url.origin;
    if (origin.isEmpty) {
      return null;
    }
    return '${origin}/api/v1/playlists/${playlist.id}';
  }
}

class AddressPlaylistReference extends PlaylistReference {
  AddressPlaylistReference(
      {required super.playlist,
      required super.url,
      required super.type,
      required this.address});

  final WalletAddress address;
}

extension PlaylistReferenceExtension on PlaylistReference {
  /// Get creator title of the playlist from cached channel reference.
  String get creator {
    final channelReference = injector<FeralFileFeedManager>()
        .getCachedChannelReferenceByPlaylist(playlist);

    return channelReference != null ? channelReference.channel.title : '';
  }
}

class ChannelReference {
  factory ChannelReference.fromJson(Map<String, dynamic> json) =>
      ChannelReference(
        channel: Channel.fromJson(json['channel'] as Map<String, dynamic>),
        url: json['url'] as String,
      );

  factory ChannelReference.fromFeralFileDP1Channel(Channel channel) =>
      ChannelReference(channel: channel, url: Environment.dp1FeedUrl);
  ChannelReference({required this.channel, required this.url});
  final Channel channel;
  final String url;

  Map<String, dynamic> toJson() => {
        'channel': channel.toJson(),
        'url': url,
      };
}

class DP1PlaylistPlaylistReferenceResponse {
  DP1PlaylistPlaylistReferenceResponse(this.items, this.hasMore, this.cursor);

  final List<PlaylistReference> items;
  final bool hasMore;
  final String? cursor;
}
