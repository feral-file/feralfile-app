
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/nft_rendering/nft_error_widget.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
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
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FFCacheNetworkImage(
                    imageUrl: '',
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
