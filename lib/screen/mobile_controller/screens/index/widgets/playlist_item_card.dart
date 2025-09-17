import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistItemCard extends StatefulWidget {
  const PlaylistItemCard({
    required this.compactedAssetToken,
    this.playlistTitle,
    super.key,
  });

  final CompactedAssetToken compactedAssetToken;
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
    final assetToken = widget.compactedAssetToken;

    listIdentities.addAll([assetToken.owner, assetToken.artistName ?? '']);
    identityBloc.add(GetIdentityEvent(listIdentities));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.compactedAssetToken.title ?? '';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        injector<NavigationService>().navigateTo(
          AppRouter.artworkDetailsPage,
          arguments: ArtworkDetailPayload(
            widget.compactedAssetToken.identity,
            useIndexer: true,
            backTitle: widget.playlistTitle,
          ),
        );
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(10),
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Center(
                  child: Builder(
                    builder: (context) {
                      return FFArtworkThumbnailView(
                        url: widget.compactedAssetToken.galleryThumbnailURL ??
                            '',
                        fit: BoxFit.fitWidth,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BlocBuilder<IdentityBloc, IdentityState>(
                  bloc: identityBloc,
                  builder: (context, identityState) {
                    final assetToken = widget.compactedAssetToken;
                    final artistName = assetToken.artistName
                            ?.toIdentityOrMask(identityState.identityMap) ??
                        assetToken.artistID ??
                        '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artistName,
                          style: Theme.of(context).textTheme.ppMori700White12,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          // italic
                          style: Theme.of(context)
                              .textTheme
                              .ppMori700White12
                              .copyWith(fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
