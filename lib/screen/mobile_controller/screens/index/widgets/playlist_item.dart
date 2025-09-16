import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';

class PlaylistItem extends StatelessWidget {
  const PlaylistItem({
    required this.playlist,
    this.channel,
    this.dividerColor = AppColor.primaryBlack,
    this.channelVisible = true,
    this.isFromPlaylistsPage = false,
    this.clickable = true,
    super.key,
  });

  final DP1Call playlist;
  final Channel? channel;
  final Color dividerColor;
  final bool channelVisible;
  final bool isFromPlaylistsPage;
  final bool clickable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        if (!clickable) return;
        injector<NavigationService>().navigateTo(
          AppRouter.dp1PlaylistDetailsPage,
          arguments: DP1PlaylistDetailsScreenPayload(
            playlist: playlist,
            backTitle: isFromPlaylistsPage ? 'Playlists' : channel?.title,
            isFromFeedServer: true,
          ),
        );
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.paddingHorizontal,
                vertical: 16,
              ),
              child: Row(
                children: [
                  // Playlist info
                  Expanded(
                    child: Text(
                      playlist.title,
                      style: theme.textTheme.ppMori400White12,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (channel != null && channelVisible)
                    GestureDetector(
                      onTap: () {
                        injector<NavigationService>().navigateTo(
                          AppRouter.channelDetailPage,
                          arguments: ChannelDetailPagePayload(
                            channel: channel!,
                            backTitle: isFromPlaylistsPage
                                ? 'Playlists'
                                : playlist.title,
                          ),
                        );
                      },
                      child: Text(
                        channel!.title,
                        style: theme.textTheme.ppMori400Grey12,
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: dividerColor,
            ),
          ],
        ),
      ),
    );
  }
}
