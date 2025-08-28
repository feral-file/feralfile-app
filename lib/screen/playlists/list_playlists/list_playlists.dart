import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/color_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/collection_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/title_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ListPlaylistsScreen extends StatefulWidget {
  final ValueNotifier<List<PlayListModel>?> playlists;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function() onAdd;
  final String filter;

  const ListPlaylistsScreen(
      {required this.playlists,
      required this.onReorder,
      required this.onAdd,
      super.key,
      this.filter = ''});

  @override
  State<ListPlaylistsScreen> createState() => _ListPlaylistsScreenState();
}

class _ListPlaylistsScreenState extends State<ListPlaylistsScreen>
    with RouteAware, WidgetsBindingObserver {
  static const int _playlistNumberBreakpoint = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<PlayListModel>?>(
        valueListenable: widget.playlists,
        builder: (context, value, child) {
          if (value == null) {
            return const SizedBox.shrink();
          }
          List<PlayListModel> playlists =
              value.filter(widget.filter).reversed.toList();
          if (playlists.isEmpty && widget.filter.isNotEmpty) {
            return const SizedBox();
          }
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Row(
                children: [
                  TitleText(title: 'playlists'.tr()),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onAdd,
                    child: Text(
                      'create'.tr(),
                      style: theme.textTheme.ppMori700White14.copyWith(
                        color: AppColor.feralFileLightBlue,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),
              _playlistHorizontalGridView(context, playlists)
            ],
          );
        },
      );

  Widget _playlistHorizontalGridView(
      BuildContext context, List<PlayListModel> playlists) {
    final rowNumber = playlists.length > _playlistNumberBreakpoint ? 2 : 1;
    final height = PlaylistItem.height * rowNumber + 15 * (rowNumber - 1);
    final length = playlists.length;
    return SizedBox(
      height: height,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: rowNumber,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: PlaylistItem.height / PlaylistItem.width,
        ),
        itemBuilder: (context, index) {
          final item = playlists[index];
          return PlaylistItem(
              key: ValueKey(item.id),
              playlist: item,
              onSelected: () async {
                if (item.id == DefaultPlaylistModel.allNfts.id) {
                  await Navigator.of(context)
                      .pushNamed(AppRouter.collectionPage);
                  return;
                }
                onPlaylistTap(item);
              });
        },
        itemCount: length,
      ),
    );
  }

  void onPlaylistTap(PlayListModel playlist) {
    unawaited(Navigator.pushNamed(
      context,
      AppRouter.viewPlayListPage,
      arguments: ViewPlaylistScreenPayload(playListModel: playlist),
    ));
  }
}

class PlaylistItem extends StatefulWidget {
  final Function()? onSelected;
  final PlayListModel playlist;
  final bool onHold;
  static const double width = 140;
  static const double height = 165;

  const PlaylistItem({
    required this.playlist,
    super.key,
    this.onSelected,
    this.onHold = false,
  });

  @override
  State<PlaylistItem> createState() => _PlaylistItemState();
}

class _PlaylistItemState extends State<PlaylistItem> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormatter = NumberFormat('#,###');
    final thumbnailURL = widget.playlist.thumbnailURL;
    final name = widget.playlist.getName();
    return GestureDetector(
      onTap: widget.onSelected,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Container(
          width: PlaylistItem.width,
          height: PlaylistItem.height,
          decoration: BoxDecoration(
            color: AppColor.white,
            border: Border.all(
              color: widget.onHold
                  ? AppColor.feralFileHighlight
                  : Colors.transparent,
              width: widget.onHold ? 2 : 0,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.ppMori400Black14,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    numberFormatter.format(widget.playlist.tokenIDs.length),
                    style: theme.textTheme.ppMori400Grey14,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Center(
                  child: thumbnailURL == null || thumbnailURL.isEmpty
                      ? Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: theme.disableColor,
                        )
                      : CachedNetworkImage(
                          imageUrl: thumbnailURL,
                          fit: BoxFit.cover,
                          cacheManager: injector<CacheManager>(),
                          placeholder: (context, url) =>
                              const GalleryThumbnailPlaceholder(),
                          errorWidget: (context, url, error) => Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: theme.disableColor,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddPlayListItem extends StatelessWidget {
  final Function()? onTap;

  const AddPlayListItem({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 165,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: theme.auLightGrey,
            ),
            color: AppColor.white),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'new_playlist'.tr(),
                    style: theme.textTheme.ppMori400Black14,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Expanded(
              child: Center(
                child: Icon(
                  AuIcon.add,
                  color: AppColor.primaryBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
