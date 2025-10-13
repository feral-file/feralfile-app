import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

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
      Duration(days: 1).toString(),
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
    if (force || shouldUpdate || kDebugMode) {
      for (final feedService in feedServices) {
        await feedService.reloadCache();
      }
      await injector<ConfigurationService>()
          .setLastTimeRefreshFeeds(DateTime.now());
      log.info(
          'Reload all cache, last time refresh feeds: $lastTimeRefreshFeeds, duration: $updateFeedDuration, force: $force');
      injector<PlaylistsBloc>().add(RefreshPlaylistsEvent());
      injector<ChannelsBloc>().add(RefreshChannelsEvent());
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

  void setupRemoteConfigChannels(List<String> channelUrls) {
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
        final service = FeralFileDP1FeedService(baseUrl: endpoint)
          ..addRemoteConfigChannelIds(channelIdsByUrl[endpoint]!);
        addFeedService(service);
      }
    }
    log.info(
        'Finish Setup remote config channels: ${remoteConfigChannels.map((e) => e.channelId).toList()}');
  }

  List<RemoteConfigChannel> remoteConfigChannels = [];

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
}

class PlaylistReference {
  PlaylistReference({required this.playlist, required this.url});
  final DP1Call playlist;
  final String url;

  factory PlaylistReference.fromJson(Map<String, dynamic> json) =>
      PlaylistReference(
        playlist: DP1Call.fromJson(json['playlist'] as Map<String, dynamic>),
        url: json['url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'playlist': playlist.toJson(),
        'url': url,
      };

  factory PlaylistReference.fromFeralFileDP1Call(DP1Call dp1Call) =>
      PlaylistReference(playlist: dp1Call, url: Environment.dp1FeedUrl);
}

class ChannelReference {
  ChannelReference({required this.channel, required this.url});
  final Channel channel;
  final String url;

  factory ChannelReference.fromJson(Map<String, dynamic> json) =>
      ChannelReference(
        channel: Channel.fromJson(json['channel'] as Map<String, dynamic>),
        url: json['url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'channel': channel.toJson(),
        'url': url,
      };

  factory ChannelReference.fromFeralFileDP1Channel(Channel channel) =>
      ChannelReference(channel: channel, url: Environment.dp1FeedUrl);
}

class DP1PlaylistPlaylistReferenceResponse {
  DP1PlaylistPlaylistReferenceResponse(this.items, this.hasMore, this.cursor);

  factory DP1PlaylistPlaylistReferenceResponse.fromJson(
          Map<String, dynamic> json) =>
      DP1PlaylistPlaylistReferenceResponse(
        (json['items'] as List<dynamic>)
            .map((e) => PlaylistReference.fromJson(e as Map<String, dynamic>))
            .toList(),
        json['hasMore'] as bool,
        json['cursor'] as String?,
      );

  final List<PlaylistReference> items;
  final bool hasMore;
  final String? cursor;
}
