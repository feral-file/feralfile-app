import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_list_response.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_artwork_preview/feralfile_artwork_preview_page.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_state.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:autonomy_flutter/view/series_title_view.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:sentry/sentry.dart';

class FeralFileSeriesPage extends StatefulWidget {
  const FeralFileSeriesPage({required this.payload, super.key});

  final FeralFileSeriesPagePayload payload;

  @override
  State<FeralFileSeriesPage> createState() => _FeralFileSeriesPageState();
}

class _FeralFileSeriesPageState extends State<FeralFileSeriesPage> {
  late final FeralFileSeriesBloc _feralFileSeriesBloc;
  final _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
  static const _padding = 14.0;
  static const _axisSpacing = 5.0;

  PagingState<int, Artwork> _pageState = PagingState<int, Artwork>();

  // PagingController(firstPageKey: 0);
  static const _pageSize = 300;

  @override
  void initState() {
    super.initState();
    _feralFileSeriesBloc = context.read<FeralFileSeriesBloc>();
    _feralFileSeriesBloc.add(FeralFileSeriesGetSeriesEvent(
        widget.payload.seriesId, widget.payload.exhibitionId));
    // _pagingController.addPageRequestListener((pageKey) async {
    //   await _fetchPage(context, pageKey);
    // });
  }

  Future<void> _fetchPage(BuildContext context, int pageKey) async {
    try {
      final newItems = await injector<FeralFileService>().getSeriesArtworks(
          widget.payload.seriesId, widget.payload.exhibitionId,
          offset: pageKey,
          // ignore: avoid_redundant_argument_values
          limit: _pageSize);
      final isLastPage = !(newItems.paging?.shouldLoadMore ?? false);
      if (isLastPage) {
        // _pagingController.appendLastPage(newItems.result);
        // return newItems.result;
      } else {
        final nextPageKey = pageKey + _pageSize;
        if (context.mounted) {
          // make sure the page is not disposed
          // _pagingController.appendPage(newItems.result, nextPageKey);
          // return newItems.result;
        }
      }
    } catch (error) {
      log.info('Error fetching series page: $error');
      unawaited(Sentry.captureException(error));
    }
  }

  Future<void> _fetchNextPage() async {
    if (_pageState.isLoading) return;

    setState(() {
      _pageState = _pageState.copyWith(isLoading: true, error: null);
    });

    try {
      final newKey = (_pageState.keys?.last ?? 0) + 1;
      final newItems = await injector<FeralFileService>().getSeriesArtworks(
          widget.payload.seriesId, widget.payload.exhibitionId,
          offset: newKey,
          // ignore: avoid_redundant_argument_values
          limit: _pageSize);
      final isLastPage = !(newItems.paging?.shouldLoadMore ?? false);

      setState(() {
        _pageState = _pageState.copyWith(
          pages: [...?_pageState.pages, newItems.result],
          keys: [...?_pageState.keys, newKey],
          hasNextPage: !isLastPage,
          isLoading: false,
        );
      });
    } catch (error) {
      log.info('Error fetching series page: $error');
      unawaited(Sentry.captureException(error));
      setState(() {
        _pageState = _pageState.copyWith(
          error: error,
          isLoading: false,
        );
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<FeralFileSeriesBloc, FeralFileSeriesState>(
        builder: (context, state) => Scaffold(
            appBar: _getAppBar(context, state.series),
            backgroundColor: AppColor.primaryBlack,
            body: _body(context, state.series, state.thumbnailRatio)),
        listener: (context, state) {},
      );

  AppBar _getAppBar(BuildContext buildContext, FFSeries? series) => getFFAppBar(
        buildContext,
        onBack: () => Navigator.pop(buildContext),
        title: series == null
            ? const SizedBox()
            : SeriesTitleView(
                series: series,
                artist: series.artistAlumni,
                crossAxisAlignment: CrossAxisAlignment.center),
      );

  Widget _body(BuildContext context, FFSeries? series, double? thumbnailRatio) {
    if (series == null) {
      return _loadingIndicator();
    }
    return _artworkSliverGrid(context, series, thumbnailRatio ?? 1);
  }

  Widget _loadingIndicator() => Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: loadingIndicator(valueColor: AppColor.auGrey),
        ),
      );

  Widget _artworkSliverGrid(
      BuildContext context, FFSeries series, double ratio) {
    final cacheWidth =
        (MediaQuery.sizeOf(context).width - _padding * 2 - _axisSpacing * 2) ~/
            3;
    final cacheHeight = (cacheWidth / ratio).toInt();
    return Padding(
      padding:
          const EdgeInsets.only(left: _padding, right: _padding, bottom: 20),
      child: CustomScrollView(
        slivers: [
          PagedSliverGrid<int, Artwork>(
            state: _pageState,
            fetchNextPage: _fetchNextPage,
            showNewPageErrorIndicatorAsGridChild: false,
            showNewPageProgressIndicatorAsGridChild: false,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisSpacing: _axisSpacing,
              mainAxisSpacing: _axisSpacing,
              crossAxisCount: 3,
              childAspectRatio: ratio,
            ),
            builderDelegate: PagedChildBuilderDelegate<Artwork>(
              itemBuilder: (context, artwork, index) => FFArtworkThumbnailView(
                url: artwork.thumbnailURL,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                onTap: () async {
                  final displayKey = series.displayKey;
                  final lastSelectedCanvasDevice = _canvasDeviceBloc.state
                      .lastSelectedActiveDeviceForKey(displayKey);

                  if (lastSelectedCanvasDevice != null) {
                    final castRequest = CastExhibitionRequest(
                        exhibitionId: series.exhibitionID,
                        catalog: ExhibitionCatalog.artwork,
                        catalogId: artwork.id);
                    final completer = Completer<void>();
                    _canvasDeviceBloc.add(
                      CanvasDeviceCastExhibitionEvent(
                        lastSelectedCanvasDevice,
                        castRequest,
                        onDone: () {
                          completer.complete();
                        },
                      ),
                    );
                    await completer.future;
                  }
                  await Navigator.of(context).pushNamed(
                    AppRouter.ffArtworkPreviewPage,
                    arguments: FeralFileArtworkPreviewPagePayload(
                      artworkId: artwork.id,
                      isFromExhibition: true,
                    ),
                  );
                },
              ),
              newPageProgressIndicatorBuilder: (context) => _loadingIndicator(),
              firstPageErrorIndicatorBuilder: (context) => const SizedBox(),
              newPageErrorIndicatorBuilder: (context) => const SizedBox(),
            ),
          )
        ],
      ),
    );
  }
}

class FeralFileSeriesPagePayload {
  final String seriesId;
  final String exhibitionId;

  const FeralFileSeriesPagePayload({
    required this.seriesId,
    required this.exhibitionId,
  });
}
