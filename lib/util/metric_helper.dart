import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/metric/dp1_playlist_metric.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/service/metric_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MetricHelper {
  static Future<void> trackViewPlaylist({
    required PlaylistReference playlist,
  }) async {
    // useẻ
    final userId = await injector<AuthService>().getOrGenerateUserId();

    // package info
    final packageInfo = await PackageInfo.fromPlatform();

    final buildType = packageInfo.packageName.contains('inhouse')
        ? 'development'
        : 'production';

    // device info
    final deviceInfoService = injector<DeviceInfoService>();
    final deviceOSVersion = deviceInfoService.deviceOSVersion;

    // build type
    final playlistUrl = playlist.fullUrl;
    final playlistScope = playlist.type == PlaylistReferenceType.channel
        ? PlaylistScope.feed
        : PlaylistScope.generated;
    final playlistFeedHost = playlist.url.origin;

    final playlistKey = '${playlist.playlist.title}|${playlist.playlist.id}';

    final payload = ViewPLaylistMetricPayload(
      profileId: userId,
      playlistId: playlist.playlist.id,
      envApp: 'ff-controller',
      envAppVersion: packageInfo.version,
      envPlatform: Platform.isIOS ? 'ios' : 'android',
      envOs: deviceInfoService.deviceOSName,
      envOsVersion: deviceOSVersion,
      envBuildType: buildType,
      playlistScope: playlistScope,
      playlistKey: playlistKey,
      playlistUrl: playlistUrl,
      playlistDp1Version: playlist.playlist.dpVersion,
      playlistFeedHost: playlistFeedHost,
    );

    await injector<MetricService>().trackEvent(
      event: MetricEvent.view_playlist,
      properties: payload.toJson(),
    );
  }
}
