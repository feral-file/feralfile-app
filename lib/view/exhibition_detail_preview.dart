import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/view/ff_exhibition_participants.dart';
import 'package:autonomy_flutter/view/john_gerrard_live_performance.dart';
import 'package:autonomy_flutter/view/title_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

class ExhibitionPreview extends StatelessWidget {
  final Exhibition exhibition;

  const ExhibitionPreview({required this.exhibition, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subTitleTextStyle = theme.textTheme.ppMori400Grey12
        .copyWith(color: AppColor.feralFileMediumGrey);
    final participantTextStyle = theme.textTheme.ppMori400White16.copyWith(
      decorationColor: Colors.white,
    );

    final listCurators =
        (exhibition.curatorAlumni != null || exhibition.curatorsAlumni != null)
            ? exhibition.id == SOURCE_EXHIBITION_ID
                ? exhibition.curatorsAlumni!
                : [exhibition.curatorAlumni!]
            : <AlumniAccount>[];

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildExhibitionMedia(context, exhibition),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: TitleText(
              title: exhibition.title,
              ellipsis: false,
            ),
          ),
          if (listCurators.isNotEmpty) ...[
            Text(
              listCurators.length > 1 ? 'curators'.tr() : 'curator'.tr(),
              style: subTitleTextStyle,
            ),
            const SizedBox(height: 3),
            FFExhibitionParticipants(
              listAlumni: listCurators,
              textStyle: participantTextStyle,
            ),
          ],
          const SizedBox(height: 10),
          Text(
              exhibition.isGroupExhibition
                  ? 'group_exhibition'.tr()
                  : 'solo_exhibition'.tr(),
              style: subTitleTextStyle),
          const SizedBox(height: 3),
          FFExhibitionParticipants(
            listAlumni: exhibition.artistsAlumni!,
            textStyle: participantTextStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildExhibitionMedia(BuildContext context, Exhibition exhibition) {
    if (exhibition.id == SOURCE_EXHIBITION_ID) {
      return _buildSourceExhibitionCover(context);
    } else if (exhibition.isJohnGerrardShow) {
      return _buildJohnGerrardExhibitionLivePerformance(context);
    } else {
      return CachedNetworkImage(
        imageUrl: exhibition.coverUrl,
        cacheManager: injector<CacheManager>(),
        fit: BoxFit.fitWidth,
      );
    }
  }

  Widget _buildSourceExhibitionCover(BuildContext context) {
    const padding = 14.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final estimatedHeight = (screenWidth - padding * 2) / 16 * 9;
    return SvgPicture.network(
      exhibition.coverUrl,
      height: estimatedHeight,
      fit: BoxFit.fitWidth,
      placeholderBuilder: (context) => SizedBox(
        height: estimatedHeight,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            backgroundColor: AppColor.auQuickSilver,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildJohnGerrardExhibitionLivePerformance(BuildContext context) {
    const padding = 14.0;
    return SizedBox(
      height: MediaQuery.sizeOf(context).width - padding * 2,
      child: JohnGerrardLivePerformanceWidget(
        exhibition: exhibition,
      ),
    );
  }
}
