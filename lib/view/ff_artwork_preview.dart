import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/feralfile_artwork_preview/feralfile_artwork_preview_page.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_page.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/view/feralfile_artwork_preview_widget.dart';
import 'package:autonomy_flutter/view/series_title_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class FeralFileArtworkPreview extends StatelessWidget {
  const FeralFileArtworkPreview({required this.payload, super.key});

  final FeralFileArtworkPreviewPayload payload;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildArtworkPreview(),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: GestureDetector(
              onTap: () async {
                final artwork = payload.artwork;
                if (artwork.series?.isSingle ?? false) {
                  await Navigator.of(context).pushNamed(
                    AppRouter.ffArtworkPreviewPage,
                    arguments: FeralFileArtworkPreviewPagePayload(
                      artworkId: artwork.id,
                      isFromExhibition: true,
                    ),
                  );
                } else {
                  await Navigator.of(context).pushNamed(
                    AppRouter.feralFileSeriesPage,
                    arguments: FeralFileSeriesPagePayload(
                      seriesId: artwork.series!.id,
                      exhibitionId: artwork.series!.exhibitionID,
                    ),
                  );
                }
              },
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 5,
                      child: SeriesTitleView(
                        series: payload.artwork.series!,
                        artist: payload.artwork.series!.artistAlumni,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 60),
                      child: SvgPicture.asset(
                        'assets/images/icon_series.svg',
                        width: 22,
                        height: 22,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildArtworkPreview() => FeralfileArtworkPreviewWidget(
        key: Key('feralfile_artwork_preview_widget_${payload.artwork.id}'),
        payload: FeralFileArtworkPreviewWidgetPayload(
          artwork: payload.artwork,
          isMute: true,
        ),
      );
}

class FeralFileArtworkPreviewPayload {
  final Artwork artwork;

  const FeralFileArtworkPreviewPayload({
    required this.artwork,
  });
}
