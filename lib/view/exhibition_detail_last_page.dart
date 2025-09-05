import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExhibitionDetailLastPage extends StatelessWidget {
  const ExhibitionDetailLastPage(
      {required this.startOver, super.key, this.nextPayload});

  final Function() startOver;
  final ExhibitionDetailPayload? nextPayload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColor.auGreyBackground,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: GestureDetector(
                  onTap: startOver,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'start_over'.tr(),
                          style: theme.textTheme.ppMori400White14,
                        ),
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          'assets/images/start_over.svg',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (nextPayload != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'next_exhibition'.tr(),
                  style: theme.textTheme.ppMori400White14,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).popAndPushNamed(
                      AppRouter.exhibitionDetailPage,
                      arguments: nextPayload,
                    );
                  },
                  child: SizedBox(
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl:
                          nextPayload!.exhibitions[nextPayload!.index].coverUrl,
                      height: 140,
                      alignment: Alignment.topCenter,
                      fit: BoxFit.fitWidth,
                      cacheManager: injector<CacheManager>(),
                    ),
                  ),
                )
              ],
            ),
        ],
      ),
    );
  }
}
