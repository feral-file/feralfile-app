import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/screen/feralfile_artwork_preview/feralfile_artwork_preview_page.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_page.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class FfSeriesInfoThumbnail extends StatefulWidget {
  final FFSeries series;

  const FfSeriesInfoThumbnail({required this.series, super.key});

  @override
  State<FfSeriesInfoThumbnail> createState() => _FfSeriesInfoThumbnailState();
}

class _FfSeriesInfoThumbnailState extends State<FfSeriesInfoThumbnail> {
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    return _navigating
        ? const LoadingWidget()
        : GestureDetector(
            onTap: () async {
              await _gotoSeriesDetails(context, series);
            },
            child: ColoredBox(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FFCacheNetworkImage(
                            imageUrl: series.thumbnailUrl ?? '',
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _seriesInfo(context, series),
                ],
              ),
            ),
          );
  }

  Future<void> _gotoSeriesDetails(BuildContext context, FFSeries series) async {
    if (series.isSingle) {
      setState(() {
        _navigating = true;
      });
      final artwork =
          await injector<FeralFileService>().getFirstViewableArtwork(series.id);
      if (artwork != null) {
        if (context.mounted) {
          unawaited(Navigator.of(context).pushNamed(
            AppRouter.ffArtworkPreviewPage,
            arguments: FeralFileArtworkPreviewPagePayload(
              artworkId: artwork.id,
            ),
          ));
        }
      }
      if (context.mounted) {
        setState(() {
          _navigating = false;
        });
      }
    } else {
      unawaited(Navigator.of(context).pushNamed(
        AppRouter.feralFileSeriesPage,
        arguments: FeralFileSeriesPagePayload(
          seriesId: series.id,
          exhibitionId: series.exhibitionID,
        ),
      ));
    }
  }

  Widget _seriesInfo(BuildContext context, FFSeries series) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.ppMori400White12;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                series.artistAlumni?.displayAlias ?? '',
                style: defaultStyle,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                series.displayTitle,
                style: defaultStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (series.exhibition != null) ...[
                const SizedBox(height: 12),
                RichText(
                  textScaler: MediaQuery.textScalerOf(context),
                  text: TextSpan(
                    style: defaultStyle.copyWith(color: AppColor.auQuickSilver),
                    children: [
                      TextSpan(
                        text: '${'exhibited_in'.tr()} ',
                      ),
                      TextSpan(
                        text: series.exhibition!.title,
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _gotoExhibitionDetails(context, series.exhibition!);
                          },
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        )
      ],
    );
  }

  void _gotoExhibitionDetails(BuildContext context, Exhibition exhibition) {
    unawaited(Navigator.of(context).pushNamed(AppRouter.exhibitionDetailPage,
        arguments: ExhibitionDetailPayload(
          exhibitions: [exhibition],
          index: 0,
        )));
  }
}
