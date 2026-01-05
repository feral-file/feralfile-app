import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PlaylistDetailsHeader extends StatelessWidget {
  const PlaylistDetailsHeader({
    required this.playlistReference,
    this.titleSuffix,
    this.total,
    this.channelReference,
    this.dividerColor = AppColor.primaryBlack,
    this.channelVisible = true,
    this.isFromPlaylistsPage = false,
    this.clickable = true,
    this.options = const [],
    super.key,
  });

  final PlaylistReference playlistReference;
  final String? titleSuffix;
  final int? total;
  final ChannelReference? channelReference;
  final Color dividerColor;
  final bool channelVisible;
  final bool isFromPlaylistsPage;
  final bool clickable;
  final List<OptionItem> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = playlistReference.playlist;
    return GestureDetector(
      onTap: () {
        if (!clickable) return;
        injector<NavigationService>().navigateTo(
          AppRouter.dp1PlaylistDetailsPage,
          arguments: DP1PlaylistDetailsScreenPayload(
            playlist: playlistReference,
            backTitle: isFromPlaylistsPage
                ? 'Playlists'
                : channelReference?.channel.title,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Playlist info
                        Row(
                          children: [
                            Text(
                              playlist.title,
                              style: AppTypography.body(context).white,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (total != null) ...[
                              SizedBox(width: LayoutConstants.space1),
                              Text(
                                '($total)',
                                style: AppTypography.bodySmall(context).grey,
                              ),
                            ],
                            if (titleSuffix != null) ...[
                              SizedBox(width: LayoutConstants.space1),
                              Text(
                                titleSuffix!,
                                style: AppTypography.bodySmall(context).grey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        if (channelReference != null && channelVisible)
                          GestureDetector(
                            onTap: () {
                              injector<NavigationService>().navigateTo(
                                AppRouter.channelDetailPage,
                                arguments: ChannelDetailPagePayload(
                                  channelReference: channelReference!,
                                  backTitle: isFromPlaylistsPage
                                      ? 'Playlists'
                                      : playlist.title,
                                ),
                              );
                            },
                            child: Text(
                              channelReference!.channel.title,
                              style: AppTypography.body(context).grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (options.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async => _showPlaylistOptionsDialog(
                        context,
                        playlistReference,
                      ),
                      constraints: const BoxConstraints(
                        maxWidth: 44,
                        maxHeight: 44,
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: SvgPicture.asset(
                        'assets/images/more_circle.svg',
                      ),
                    )
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

  Future<void> _showPlaylistOptionsDialog(
    BuildContext context,
    PlaylistReference playlistReference,
  ) async {
    await UIHelper.showDrawerAction(
      context,
      options: [
        ...options,
        OptionItem.emptyOptionItem,
      ],
    );
  }
}
