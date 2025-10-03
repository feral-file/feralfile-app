import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/util/log.dart';
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

  Future<BaseDP1FeedServiceImpl> addFeedService(
      BaseDP1FeedServiceImpl feedService) async {
    if (isFeedServiceExists(feedService.baseUrl)) {
      log.info('Feed service already exists for url: ${feedService.baseUrl}');
      return getFeedServiceByUrl(feedService.baseUrl)!;
    }
    _feedServices.add(Pair(feedService.baseUrl, feedService));
    await feedService.reloadCache();
    return feedService;
  }

  Future<void> addFeedServiceByUrls(List<String> urls) async {
    final futures = urls.map((url) async {
      if (isFeedServiceExists(url)) {
        log.info('Feed service already exists for url: $url');
        return;
      }
      final feedService = BaseDP1FeedServiceImpl(baseUrl: url);
      await addFeedService(feedService);
    });
    await Future.wait(futures);
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

  Future<void> reloadAllCache() async {
    for (final feedService in feedServices) {
      await feedService.reloadCache();
    }
  }

  Future<List<DP1Call>> fetchAllPlaylists() async {
    List<DP1Call> allPlaylists = [];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final playlists = await feedService.getAllPlaylists();
        allPlaylists.addAll(playlists.items);
      }
    }
    return allPlaylists;
  }

  Future<List<DP1Call>> getAllCachedPlaylists() async {
    List<DP1Call> allPlaylists = [];
    for (final feedService in feedServices) {
      final playlists = await feedService.getAllPlaylists(usingCache: true);
      allPlaylists.addAll(playlists.items);
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

  void _setupDefault() {
    // final defaultUrl = Environment.dp1FeedUrl;
    // final feralFileFeedService = FeralFileDP1FeedService(baseUrl: defaultUrl);
    // addFeedService(feralFileFeedService);
    addFeedServiceByUrls([
      'https://dp1-feed-operator-api-dev.objkt-com.workers.dev',
      // 'https://dp1-feed-operator-api-prod.autonomy-system.workers.dev'
    ]);
    if (_remoteConfigChannelUrls != null) {
      setupRemoteConfigChannels(_remoteConfigChannelUrls!);
    }
  }

  void setupRemoteConfigChannels(List<String> channelUrls) {
    final remoteConfigChannels = channelUrls.map((url) {
      final uri = Uri.parse(url);
      return RemoteConfigChannel(
        endpoint: uri.origin,
        channelId: uri.pathSegments.last,
      );
    }).toList();
    this.remoteConfigChannels = remoteConfigChannels;

    for (final channel in remoteConfigChannels) {
      final existingService = getFeedServiceByUrl(channel.endpoint);
      if (existingService != null) {
        (existingService as FeralFileDP1FeedService)
            .addRemoteConfigChannelIds([channel.channelId]);
        continue;
      } else {
        final service = FeralFileDP1FeedService(baseUrl: channel.endpoint)
          ..addRemoteConfigChannelIds([channel.channelId]);
        addFeedService(service);
      }
    }
    log.info(
        'Setup remote config channels: ${remoteConfigChannels.map((e) => e.channelId).toList()}');
  }

  List<String>? get remoteConfigChannelIds =>
      remoteConfigChannels.map((channel) => channel.channelId).toList();

  List<String>? get _remoteConfigChannelUrls => [
        'https://dp1-feed-operator-api-prod.autonomy-system.workers.dev/api/v1/channels/dae709d7-26da-4b4c-b881-39cd681cc82f',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/cb3455c2-7122-4414-a9f5-7ccbe434de21',
        // 'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/5b467722-202d-44d2-af77-4c438c7f2258',
        // 'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/21f9b1a1-7ad6-4752-ba2c-3f675c4dea63',
        // 'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/92c75624-10ee-403b-81eb-0da0011d4dde',
        // 'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/70930b59-04cc-49e0-a982-7ffc17210add',
      ];

  List<RemoteConfigChannel> remoteConfigChannels = [];

  Future<List<Channel>> fetchAllChannels() async {
    List<Channel> allChannels = [];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channels = await feedService.getAllChannels();
        allChannels.addAll(channels.items);
      }
    }
    return allChannels;
  }

  Future<List<Channel>> getAllCachedChannels() async {
    List<Channel> allChannels = [];
    for (final feedService in feedServices) {
      if (feedService is FeralFileDP1FeedService) {
        final channels = await feedService.getAllChannels(usingCache: true);
        allChannels.addAll(channels.items);
      }
    }
    return allChannels;
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
