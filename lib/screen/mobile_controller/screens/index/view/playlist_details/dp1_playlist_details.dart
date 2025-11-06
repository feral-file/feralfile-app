import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_item.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/feed_registry_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/dp1_playlist_grid_view.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sentry/sentry.dart';

class DP1PlaylistDetailsScreenPayload {
  const DP1PlaylistDetailsScreenPayload({
    required this.playlist,
    this.backTitle,
    this.isFromFeedServer = false,
  });

  final PlaylistReference playlist;
  final String? backTitle;
  final bool isFromFeedServer;
}

class DP1PlaylistDetailsScreen extends StatefulWidget {
  const DP1PlaylistDetailsScreen({required this.payload, super.key});

  final DP1PlaylistDetailsScreenPayload payload;

  @override
  State<DP1PlaylistDetailsScreen> createState() =>
      _DP1PlaylistDetailsScreenState();
}

class _DP1PlaylistDetailsScreenState extends State<DP1PlaylistDetailsScreen> {
  CanvasDeviceBloc get _canvasDeviceBloc => injector<CanvasDeviceBloc>();

  @override
  Widget build(BuildContext context) {
    final playlistReference = widget.payload.playlist;
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: _canvasDeviceBloc,
      builder: (context, state) {
        return Scaffold(
          appBar: CustomAppBar(
            backTitle: widget.payload.backTitle ?? 'Playlists',
            actions: [
              FFCastButton(
                // displayKey: widget.payload.playlist.id,
                onDeviceSelected: (device) {
                  final completer = Completer<void>();
                  _canvasDeviceBloc.add(
                    CanvasDeviceCastDP1PlaylistEvent(
                      device: device,
                      playlist: widget.payload.playlist.playlist,
                      intent: DP1Intent.displayNow(),
                      usingUrl: false, //widget.payload.isFromFeedServer,
                      onDoneCallback: () {
                        completer.complete();
                      },
                    ),
                  );
                  return completer.future;
                },
              ),
              if (playlistReference.isExternalFeedService)
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
                ),
            ],
          ),
          backgroundColor: AppColor.auGreyBackground,
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final playlistReference = widget.payload.playlist;
    final url = playlistReference.url;
    final playlist = playlistReference.playlist;
    final feedService =
        injector<FeralFileFeedManager>().getFeedServiceByUrl(url);
    final channel = (feedService is FeralFileDP1FeedService)
        ? feedService.getChannelByPlaylistId(playlist.id)
        : null;
    final channelReference =
        channel != null ? ChannelReference(channel: channel, url: url) : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PlaylistAssetGridView(
            header: Column(
              children: [
                const SizedBox(height: UIConstants.detailPageHeaderPadding),
                if (playlist.title.isNotEmpty)
                  PlaylistItem(
                    playlistReference: playlistReference,
                    channelReference: channelReference,
                    clickable: false,
                  )
              ],
            ),
            playlist: playlist,
          ),
        ),
      ],
    );
  }

  Future<void> _showPlaylistOptionsDialog(
    BuildContext context,
    PlaylistReference playlistReference,
  ) async {
    await UIHelper.showDrawerAction(
      context,
      options: [
        OptionItem(
          title: 'Publish to Feral File',
          icon: const Icon(Icons.cloud_upload),
          onTap: () async {
            try {
              final request = DP1CreatePlaylistRequest.fromDP1Call(
                  playlistReference.playlist);
              await injector<FeralFileDP1FeedService>()
                  .createPlaylist(request: request);
              unawaited(UIHelper.showInfoDialog(
                  context,
                  'Playlist published successfully',
                  'Your playlist has been published.'));
            } catch (e) {
              log.info('Failed to publish playlist to Feral File: $e');
              unawaited(
                  Sentry.captureException('Failed to publish playlist: $e'));
              unawaited(
                UIHelper.showMessageAction(
                  context,
                  'Failed to publish playlist',
                  '',
                  descriptionWidget: Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      return RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(text: 'Unable to publish playlist '),
                            TextSpan(
                                text: playlistReference.playlist.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const TextSpan(
                              text:
                                  '. Please try again later. If the issue persists, please contact support.',
                            ),
                          ],
                          style: theme.primaryTextTheme.ppMori400White12,
                        ),
                      );
                    },
                  ),
                  actionButton: 'Help',
                  onAction: () {
                    injector<NavigationService>().navigateTo(
                        AppRouter.supportThreadPage,
                        arguments: NewIssuePayload(
                            reportIssueType: ReportIssueType.Bug));
                  },
                ),
              );
            }
          },
        ),
        OptionItem(
          title: 'Star Playlist',
          icon: const Icon(Icons.star),
          onTap: () async {
            try {
              await injector<FeedRegistryService>()
                  .starPlaylist(playlistReference);
              unawaited(UIHelper.showInfoDialog(
                  context,
                  'Playlist starred successfully',
                  'Your playlist has been starred.'));
            } catch (e) {
              log.info('Failed to star playlist: $e');
              unawaited(Sentry.captureException('Failed to star playlist: $e'));
              unawaited(
                UIHelper.showMessageAction(
                  context,
                  'Failed to star playlist',
                  '',
                  descriptionWidget: Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      return RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(text: 'Unable to star playlist '),
                            TextSpan(
                                text: playlistReference.playlist.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const TextSpan(
                              text:
                                  '. Please try again later. If the issue persists, please contact support.',
                            ),
                          ],
                          style: theme.primaryTextTheme.ppMori400White12,
                        ),
                      );
                    },
                  ),
                  actionButton: 'Help',
                  onAction: () {
                    injector<NavigationService>().navigateTo(
                        AppRouter.supportThreadPage,
                        arguments: NewIssuePayload(
                            reportIssueType: ReportIssueType.Bug));
                  },
                ),
              );
            }
          },
        ),
        OptionItem.emptyOptionItem,
      ],
    );
  }
}
