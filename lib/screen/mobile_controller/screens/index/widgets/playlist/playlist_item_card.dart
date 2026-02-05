import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistItemCard extends StatefulWidget {
  const PlaylistItemCard({
    required this.nowDisplayingItem,
    this.playlistTitle,
    super.key,
  });

  final DP1NowDisplayingItem nowDisplayingItem;
  final String? playlistTitle;

  @override
  State<PlaylistItemCard> createState() => _PlaylistItemCardState();
}

class _PlaylistItemCardState extends State<PlaylistItemCard> {
  final identityBloc = injector<IdentityBloc>();

  @override
  void initState() {
    _fetchIdentity();
    super.initState();
  }

  void _fetchIdentity() {
    final listIdentities = <String>[];
    final artistNames =
        widget.nowDisplayingItem.artists.map((e) => e.name).toList();
    listIdentities.addAll(artistNames);
    identityBloc.add(GetIdentityEvent(listIdentities));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.nowDisplayingItem.title ?? 'Unknown Title';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.nowDisplayingItem.assetToken != null
          ? () {
              injector<NavigationService>().navigateTo(
                AppRouter.artworkDetailsPage,
                arguments: ArtworkDetailPayload(
                  widget.nowDisplayingItem.assetToken!.identity,
                  useIndexer: true,
                  backTitle: widget.playlistTitle,
                ),
              );
            }
          : null,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(12),
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ClipRect(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: _thumbnail(context),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              BlocBuilder<IdentityBloc, IdentityState>(
                bloc: identityBloc,
                builder: (context, identityState) {
                  final artistName = widget.nowDisplayingItem
                      .displayArtists(identityState.identityMap);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        artistName,
                        style: AppTypography.body(context).white.italic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        title,
                        // italic
                        style: AppTypography.bodyBold(context).white,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context) {
    final url = widget.nowDisplayingItem.thumbnail?.uri;
    if (url == null || url.isEmpty) {
      return const GalleryNoThumbnailWidget();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return FFArtworkThumbnailView(
          url: url,
          fit: BoxFit.contain,
          cacheWidth: constraints.maxWidth.toInt(),
          cacheHeight: constraints.maxHeight.toInt(),
        );
      },
    );
  }
}
