import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/playlist_activation.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marqueer/marqueer.dart';

class PlaylistActivationPagePayload {
  final PlaylistActivation activation;

  PlaylistActivationPagePayload({required this.activation});
}

class PlaylistActivationPage extends StatefulWidget {
  final PlaylistActivationPagePayload payload;

  const PlaylistActivationPage({required this.payload, super.key});

  @override
  State<PlaylistActivationPage> createState() => _PlaylistActivationPageState();
}

class _PlaylistActivationPageState extends State<PlaylistActivationPage> {
  @override
  Widget build(BuildContext context) {
    final activation = widget.payload.activation;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: getDarkEmptyAppBar(),
      backgroundColor: AppColor.primaryBlack,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: AppColor.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 30,
                      child: Marqueer(
                        direction: MarqueerDirection.ltr,
                        pps: 30,
                        child: Text(
                          'gift_playlist'.tr().toUpperCase(),
                          style: theme.textTheme.ppMori400Black14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 28),
                        child: FFCacheNetworkImage(
                            imageUrl: activation.thumbnailURL),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 30,
                      child: Marqueer(
                        pps: 30,
                        child: Text(
                          'gift_playlist'.tr().toUpperCase(),
                          style: theme.textTheme.ppMori400Black14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activation.name,
                          style: theme.textTheme.ppMori400White14,
                        ),
                        Text(
                          '${activation.playListModel.tokenIDs.length} '
                          '${'artworks_from_FF_and_artworld'.tr()}',
                          style: theme.textTheme.ppMori400White14,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  SvgPicture.asset(
                    'assets/images/penrose_moma.svg',
                    height: 28,
                    colorFilter:
                        const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
            addOnlyDivider(color: AppColor.auGreyBackground),
            const SizedBox(
              height: 16,
            ),
            _content(context, activation),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, PlaylistActivation activation) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: theme.textTheme.ppMori400White14,
              children: [
                TextSpan(text: '${'you_receive_gift_playlist'.tr()} '),
                TextSpan(
                  text: '${activation.source}.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          Text(
            'accept_and_experience_playlist'.tr(),
            style: theme.textTheme.ppMori400White14,
          ),
          const SizedBox(
            height: 24,
          ),
          PrimaryAsyncButton(
            text: 'Accept Gift',
            onTap: () async {
              final playlist = activation.playListModel;
              final playlistService = injector<PlaylistService>();
              final alreadyClaimPlaylist =
                  await playlistService.getPlaylistById(playlist.id);

              // if user already claim the playlist,
              // show already claim playlist
              if (alreadyClaimPlaylist != null) {
                injector<NavigationService>().goBack();
                unawaited(injector<NavigationService>()
                    .showALreadyClaimPlaylist(playlist: alreadyClaimPlaylist));
                return;
              }

              await playlistService.addPlaylists([playlist]);
              injector<NavigationService>().goBack();
              unawaited(injector<NavigationService>()
                  .openPlaylist(playlist: playlist));
            },
            color: AppColor.feralFileLightBlue,
          ),
          const SizedBox(
            height: 16,
          ),
          GestureDetector(
            child: Text(
              'Decline',
              style: theme.textTheme.ppMori400Grey14.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
            onTap: () {
              injector<NavigationService>().goBack();
            },
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }
}
