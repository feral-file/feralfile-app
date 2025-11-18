import 'package:autonomy_flutter/design/build/components/ArtworkItem.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:flutter/material.dart';

class DP1ItemThumbnail extends StatelessWidget {
  const DP1ItemThumbnail({
    required this.item,
    this.onTap,
    super.key,
  });

  final DP1NowDisplayingItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ArtworkItemTokens.containerWidth,
        height: ArtworkItemTokens.containerHeight,
        padding: EdgeInsets.all(ArtworkItemTokens.containerPadding),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: ArtworkItemTokens.imageWidth,
              height: ArtworkItemTokens.imageHeight,
              child: _buildThumbnail(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final thumbnailUri = item.thumbnail?.uri;

    if (thumbnailUri == null || thumbnailUri.isEmpty) {
      return const GalleryNoThumbnailWidget();
    }

    return FFArtworkThumbnailView(
      url: thumbnailUri,
      fit: BoxFit.contain,
      cacheWidth: ArtworkItemTokens.imageWidth.toInt(),
      cacheHeight: ArtworkItemTokens.imageHeight.toInt(),
    );
  }
}
