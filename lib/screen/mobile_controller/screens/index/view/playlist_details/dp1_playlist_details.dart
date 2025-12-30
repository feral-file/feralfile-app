import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_details_header.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/metric_helper.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/dp1_playlist_grid_view.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

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

class _DP1PlaylistDetailsScreenState extends State<DP1PlaylistDetailsScreen>
    with AfterLayoutMixin {
  CanvasDeviceBloc get _canvasDeviceBloc => injector<CanvasDeviceBloc>();

  late PlaylistDetailsBloc _playlistDetailsBloc;

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = injector<PlaylistDetailsBlocManager>()
        .getBloc(widget.payload.playlist.playlist);
  }

  @override
  void dispose() {
    injector<PlaylistDetailsBlocManager>()
        .releaseBlocByInstance(_playlistDetailsBloc);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DP1PlaylistDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.playlist.playlist !=
        widget.payload.playlist.playlist) {
      injector<PlaylistDetailsBlocManager>()
          .releaseBlocByInstance(_playlistDetailsBloc);
      setState(() {
        _playlistDetailsBloc = injector<PlaylistDetailsBlocManager>()
            .getBloc(widget.payload.playlist.playlist);
      });
    }
  }

  @override
  void afterFirstLayout(BuildContext context) {
    MetricHelper.trackViewPlaylist(playlist: widget.payload.playlist);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: _canvasDeviceBloc,
      builder: (context, state) {
        return Scaffold(
          appBar: MainAppBar(
            backTitle: widget.payload.backTitle ?? 'Playlists',
            actions: [
              FFCastButton(
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

    final isDynamicPlaylist = playlist.isDynamic;

    return BlocBuilder<PlaylistDetailsBloc, PlaylistDetailsState>(
      key: ValueKey(_playlistDetailsBloc.hashCode),
      bloc: _playlistDetailsBloc,
      builder: (context, state) {
        final total = state.total;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: PlaylistAssetGridView(
                header: Column(
                  children: [
                    const SizedBox(height: UIConstants.detailPageHeaderPadding),
                    if (playlist.title.isNotEmpty)
                      if (isDynamicPlaylist)
                        _dynamicPlaylistHeader(
                          playlistReference: playlistReference,
                          channelReference: channelReference,
                          state: state,
                        )
                      else
                        PlaylistDetailsHeader(
                          playlistReference: playlistReference,
                          channelReference: channelReference,
                          clickable: false,
                          options: _getOptions(playlistReference),
                        )
                  ],
                ),
                playlist: playlist,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dynamicPlaylistHeader(
      {required PlaylistReference playlistReference,
      required ChannelReference? channelReference,
      required PlaylistDetailsState state}) {
    final total = state.total;
    return BlocBuilder<UserAllOwnCollectionBloc, UserAllOwnCollectionState>(
      bloc: injector<UserAllOwnCollectionBloc>(),
      builder: (context, collectionState) {
        final owners =
            playlistReference.playlist.firstDynamicQuery?.params.owners ??
                <String>[];
        final stateSuffix = owners.isNotEmpty
            ? collectionState.addressStates
                    .firstWhereOrNull(
                        (element) => element.address.address == owners.first)
                    ?.state
                    .description ??
                ''
            : '';

        return PlaylistDetailsHeader(
          playlistReference: playlistReference,
          titleSuffix: stateSuffix,
          channelReference: channelReference,
          clickable: false,
          total: total,
          options: _getOptions(playlistReference),
        );
      },
    );
  }

  List<OptionItem> _getOptions(PlaylistReference playlistReference) {
    if (playlistReference is AddressPlaylistReference)
      return [
        OptionItem(
          title: 'Delete',
          icon: SvgPicture.asset(
            'assets/images/trash.svg',
            height: 15,
          ),
          onTap: () {
            final address = playlistReference.address;
            UIHelper.showDeleteAccountConfirmation(address, (address) async {
              await injector<AddressService>().deleteAddress(address);
              injector<NavigationService>().goBack();
              injector<NavigationService>().goBack();
            });
          },
        ),
      ];
    return [];
  }
}
