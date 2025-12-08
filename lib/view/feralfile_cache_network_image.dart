import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:octo_image/octo_image.dart';

class FFCacheNetworkImage extends CachedNetworkImage {
  FFCacheNetworkImage({
    required super.imageUrl,
    super.key,
    super.httpHeaders,
    super.imageBuilder,
    super.placeholder,
    super.progressIndicatorBuilder,
    super.errorWidget,
    super.fadeOutDuration,
    super.fadeOutCurve,
    super.fadeInDuration,
    super.fadeInCurve,
    super.width,
    super.height,
    super.fit,
    super.alignment,
    super.repeat,
    super.matchTextDirection,
    super.useOldImageOnUrlChange,
    super.color,
    super.filterQuality,
    super.colorBlendMode,
    super.placeholderFadeInDuration,
    super.memCacheWidth,
    super.memCacheHeight,
    super.cacheKey,
    super.maxWidthDiskCache,
    super.maxHeightDiskCache,
    super.errorListener,
    CacheManager? cacheManager,
    ImageRenderMethodForWeb imageRenderMethodForWeb =
        ImageRenderMethodForWeb.HtmlImage,
    double scale = 1.0,
    this.cacheScale = 3.0,
  })  : image = CachedNetworkImageProvider(
          imageUrl,
          headers: httpHeaders,
          cacheManager: cacheManager ?? injector.get<CacheManager>(),
          cacheKey: cacheKey,
          imageRenderMethodForWeb: imageRenderMethodForWeb,
          maxWidth: maxWidthDiskCache,
          maxHeight: maxHeightDiskCache,
          errorListener: errorListener,
          scale: scale,
        ),
        super(cacheManager: cacheManager ?? injector.get<CacheManager>());

  final CachedNetworkImageProvider image;
  final double cacheScale;

  @override
  int? get memCacheWidth => super.memCacheWidth == null
      ? null
      : (super.memCacheWidth! * cacheScale).toInt();

  @override
  int? get memCacheHeight => super.memCacheHeight == null
      ? null
      : (super.memCacheHeight! * cacheScale).toInt();

  @override
  int? get maxWidthDiskCache => super.maxWidthDiskCache == null
      ? null
      : (super.maxWidthDiskCache! * cacheScale).toInt();

  @override
  int? get maxHeightDiskCache => super.maxHeightDiskCache == null
      ? null
      : (super.maxHeightDiskCache! * cacheScale).toInt();

  @override
  Widget build(BuildContext context) {
    var octoPlaceholderBuilder =
        placeholder != null ? _octoPlaceholderBuilder : null;
    final octoProgressIndicatorBuilder =
        progressIndicatorBuilder != null ? _octoProgressIndicatorBuilder : null;

    ///If there is no placeholder OctoImage does not fade, so always set an
    ///(empty) placeholder as this always used to be the behaviour of
    ///CachedNetworkImage.
    if (octoPlaceholderBuilder == null &&
        octoProgressIndicatorBuilder == null) {
      octoPlaceholderBuilder = (context) => Container();
    }

    return OctoImage(
      image: image,
      imageBuilder: imageBuilder != null ? _octoImageBuilder : null,
      placeholderBuilder: octoPlaceholderBuilder,
      progressIndicatorBuilder: octoProgressIndicatorBuilder,
      errorBuilder: errorWidget != null ? _octoErrorBuilder : null,
      fadeOutDuration: fadeOutDuration,
      fadeOutCurve: fadeOutCurve,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      matchTextDirection: matchTextDirection,
      color: color,
      filterQuality: filterQuality,
      colorBlendMode: colorBlendMode,
      placeholderFadeInDuration: placeholderFadeInDuration,
      gaplessPlayback: useOldImageOnUrlChange,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
    );
  }

  Widget _octoImageBuilder(BuildContext context, Widget child) {
    return imageBuilder!(context, image);
  }

  Widget _octoPlaceholderBuilder(BuildContext context) {
    return placeholder!(context, imageUrl);
  }

  Widget _octoProgressIndicatorBuilder(
    BuildContext context,
    ImageChunkEvent? progress,
  ) {
    int? totalSize;
    var downloaded = 0;
    if (progress != null) {
      totalSize = progress.expectedTotalBytes;
      downloaded = progress.cumulativeBytesLoaded;
    }
    return progressIndicatorBuilder!(
      context,
      imageUrl,
      DownloadProgress(imageUrl, totalSize, downloaded),
    );
  }

  Widget _octoErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    log.info(
        'FFCacheNetworkImageError: url: $imageUrl, error: $error, stackTrace: $stackTrace');
    return errorWidget!(context, imageUrl, error);
  }
}
