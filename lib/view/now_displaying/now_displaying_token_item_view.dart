import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NowDisplayingTokenItemView extends StatefulWidget {
  final AssetToken assetToken;

  const NowDisplayingTokenItemView({
    required this.assetToken,
    super.key,
  });

  @override
  State<NowDisplayingTokenItemView> createState() =>
      _NowDisplayingTokenItemViewState();
}

class _NowDisplayingTokenItemViewState
    extends State<NowDisplayingTokenItemView> {
  IdentityBloc get _identityBloc => injector<IdentityBloc>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetToken = widget.assetToken;
    return BlocBuilder<IdentityBloc, IdentityState>(
      bloc: _identityBloc,
      builder: (context, state) {
        final artistTitle =
            assetToken.artistName?.toIdentityOrMask(state.identityMap) ??
                assetToken.artistName;
        // return Text(assetToken.title ?? '');
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 65, minWidth: 65),
              child: _thumbnail(context),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  artistTitle ?? '',
                  style: theme.textTheme.ppMori400Black12,
                ),
                Text(
                  assetToken.title ?? '',
                  style:
                      theme.textTheme.ppMori700Black14.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _thumbnail(BuildContext context) {
    final assetToken = widget.assetToken;
    return AspectRatio(
      aspectRatio: 67 / 37,
      child: tokenGalleryThumbnailWidget(
        context,
        CompactedAssetToken.fromAssetToken(assetToken),
        65,
        useHero: false,
      ),
    );
  }
}
