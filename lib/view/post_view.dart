import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExhibitionPostView extends StatefulWidget {
  final Post post;
  final String exhibitionID;

  const ExhibitionPostView({
    required this.post,
    required this.exhibitionID,
    super.key,
  });

  @override
  State<ExhibitionPostView> createState() => _ExhibitionPostViewState();
}

class _ExhibitionPostViewState extends State<ExhibitionPostView> {
  late String? thumbnailUrl;
  late int loadThumbnailFailedCount;

  @override
  void initState() {
    thumbnailUrl = widget.post.thumbnailUrls.firstOrNull;
    loadThumbnailFailedCount = 0;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMM d, y');
    final timeFormat = DateFormat('HH:mm');
    final dateTime = widget.post.dateTime ?? widget.post.createdAt;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColor.auGreyBackground,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.post.displayType,
                style: theme.textTheme.ppMori400White12,
              ),
              const SizedBox(height: 30),
              if (thumbnailUrl != null) ...[
                _buildThumbnailWidget(),
                const SizedBox(height: 20),
              ],
              Text(
                widget.post.title,
                style: theme.textTheme.ppMori700White14,
              ),
              if (widget.post.type != 'close-up') ...[
                const SizedBox(height: 20),
                Text(
                  '${'date'.tr()}: ${dateFormat.format(dateTime)}',
                  style: theme.textTheme.ppMori400White14,
                ),
                Text(
                  '${'time'.tr()}: ${timeFormat.format(dateTime)}',
                  style: theme.textTheme.ppMori400White14,
                ),
              ],
              if (widget.post.author?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Text(
                  '${'by_empty'.tr()} ${widget.post.author}',
                  style: theme.textTheme.ppMori400White12,
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  await injector<NavigationService>()
                      .openFeralFilePostPage(widget.post, widget.exhibitionID);
                },
                child: Text(
                  'read_more'.tr(),
                  style: theme.textTheme.ppMori400White14.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: AppColor.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailWidget() => CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.fitWidth,
        cacheManager: injector<CacheManager>(),
        errorWidget: (context, url, error) {
          loadThumbnailFailedCount++;
          if (loadThumbnailFailedCount >= widget.post.thumbnailUrls.length) {
            return const SizedBox();
          }
          thumbnailUrl = widget.post.thumbnailUrls[loadThumbnailFailedCount];
          return _buildThumbnailWidget();
        },
      );
}

class PostThumbnail extends StatelessWidget {
  final Post post;
  final int index;

  const PostThumbnail({
    required this.post,
    super.key,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) => FFCacheNetworkImage(
        imageUrl: post.thumbnailUrls[index],
        fit: BoxFit.fitWidth,
        placeholder: (context, url) => const GalleryThumbnailPlaceholder(),
        errorWidget: (context, error, stackTrace) {
          if (index >= post.thumbnailUrls.length) {
            return SvgPicture.asset('assets/images/default_avatar.svg');
          }
          return PostThumbnail(
            post: post,
            index: index + 1,
          );
        },
      );
}
