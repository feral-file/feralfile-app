import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:flutter/material.dart';

class IndexerCollectionTitleView extends StatelessWidget {
  const IndexerCollectionTitleView(
      {required this.collection,
      super.key,
      this.crossAxisAlignment,
      this.artist});

  final UserCollection collection;
  final AlumniAccount? artist;
  final CrossAxisAlignment? crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.start,
      children: [
        GestureDetector(
          child: Text(
            artist?.displayAlias ?? '',
            style: theme.textTheme.ppMori400White14,
          ),
          onTap: () async => {
            if (artist?.slug != null)
              {
                injector<NavigationService>()
                    .openFeralFileArtistPage(artist!.slug!)
              }
          },
        ),
        const SizedBox(height: 3),
        Text(
          collection.name,
          style: theme.textTheme.ppMori700White14.copyWith(
            fontStyle: FontStyle.italic,
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}
