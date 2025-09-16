import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

class FFArtworkThumbnailView extends StatelessWidget {
  const FFArtworkThumbnailView({
    required this.url,
    this.cacheWidth,
    this.cacheHeight,
    super.key,
    this.onTap,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Function? onTap;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onTap?.call(),
        child: (url.isSvgImage())
            ? SvgPicture.network(
                url,
                width: cacheWidth?.toDouble(),
                height: cacheHeight?.toDouble(),
                fit: BoxFit.cover,
                placeholderBuilder: (context) =>
                    const GalleryThumbnailPlaceholder(),
                errorBuilder: (context, error, stackTrace) =>
                    const GalleryThumbnailErrorWidget(),
              )
            : FFCacheNetworkImage(
                cacheManager: injector<CacheManager>(),
                imageUrl: url,
                memCacheWidth: cacheWidth,
                memCacheHeight: cacheHeight,
                maxWidthDiskCache: cacheWidth,
                maxHeightDiskCache: cacheHeight,
                fit: fit,
                placeholder: (context, url) =>
                    const GalleryThumbnailPlaceholder(),
                errorWidget: (context, url, error) =>
                    const GalleryThumbnailErrorWidget(),
              ),
      );
}
