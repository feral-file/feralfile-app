import 'dart:async';

import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/nft_rendering/nft_error_widget.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/indexer_collection/indexer_collection_page.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/indexer_collection_ext.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:flutter/material.dart';

class UserCollectionThumbnail extends StatefulWidget {
  final UserCollection collection;
  final AlumniAccount? artist;

  const UserCollectionThumbnail(
      {required this.collection, required this.artist, super.key});

  @override
  State<UserCollectionThumbnail> createState() =>
      _UserCollectionThumbnailState();
}

class _UserCollectionThumbnailState extends State<UserCollectionThumbnail> {
  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final artist = widget.artist;
    return GestureDetector(
      onTap: () async {
        await _gotoCollectionDetails(context, collection);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FFCacheNetworkImage(
                    imageUrl: collection.thumbnailUrl,
                    fit: BoxFit.fitWidth,
                    errorWidget: (context, url, error) =>
                        const NFTErrorWidget(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _seriesInfo(context, collection, artist),
        ],
      ),
    );
  }

  Future<void> _gotoCollectionDetails(
      BuildContext context, UserCollection userCollection) async {
    unawaited(Navigator.of(context).pushNamed(
      AppRouter.indexerCollectionPage,
      arguments: IndexerCollectionPagePayload(
        collection: userCollection,
        artist: widget.artist,
      ),
    ));
  }

  Widget _seriesInfo(
      BuildContext context, UserCollection collection, AlumniAccount? artist) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.ppMori400White12;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                artist?.displayAlias ?? '',
                style: defaultStyle,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                collection.name,
                style: defaultStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }
}
