import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_state.dart';
import 'package:autonomy_flutter/service/metric_client_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/feral_file_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/metric_helper.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/custom_note.dart';
import 'package:autonomy_flutter/view/exhibition_detail_last_page.dart';
import 'package:autonomy_flutter/view/exhibition_detail_preview.dart';
import 'package:autonomy_flutter/view/ff_artwork_preview.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/note_view.dart';
import 'package:autonomy_flutter/view/post_view.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class ExhibitionDetailPage extends StatefulWidget {
  const ExhibitionDetailPage({required this.payload, super.key});

  final ExhibitionDetailPayload payload;

  @override
  State<ExhibitionDetailPage> createState() => _ExhibitionDetailPageState();
}

class _ExhibitionDetailPageState extends State<ExhibitionDetailPage>
    with AfterLayoutMixin {
  late final ExhibitionDetailBloc _exBloc;

  final _canvasDeviceBloc = injector<CanvasDeviceBloc>();

  late final PageController _controller;
  int _currentIndex = 0;
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _exBloc = context.read<ExhibitionDetailBloc>();
    _exBloc.add(GetExhibitionDetailEvent(
        widget.payload.exhibitions[widget.payload.index].id));
    _controller = PageController();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ExhibitionDetailBloc, ExhibitionDetailState>(
          builder: (context, state) => Scaffold(
                appBar: _getAppBar(context, state.exhibition),
                backgroundColor: AppColor.auGreyBackground,
                body: _body(context, state),
              ),
          listener: (context, state) {},
          listenWhen: (previous, current) {
            if (previous.exhibition == null && current.exhibition != null) {
              _stream(current.exhibition!);
              _sendMetricViewExhibition();
            }
            return true;
          });

  Widget _body(BuildContext context, ExhibitionDetailState state) {
    final exhibition = state.exhibition;
    if (exhibition == null) {
      return const LoadingWidget();
    }

    final shouldShowNotePage = exhibition.shouldShowCuratorNotePage;
    // if exhibition is not minted, show only preview page
    final exhibitionInfoCount = shouldShowNotePage ? 3 : 2;
    final itemCount = !exhibition.isMinted
        ? exhibitionInfoCount
        : ((exhibition.displayableSeries.length) + exhibitionInfoCount);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (index < itemCount - 1) {
                _stream(exhibition);
                _sendMetricViewExhibition();
              }
            },
            scrollDirection: Axis.vertical,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == itemCount - 1) {
                return ExhibitionDetailLastPage(
                  startOver: () => setState(() {
                    _currentIndex = 0;
                    _controller.jumpToPage(0);
                  }),
                  nextPayload: widget.payload.next(),
                );
              }

              switch (index) {
                case 0:
                  return _getPreviewPage(exhibition);
                case 1:
                  if (shouldShowNotePage) {
                    return _notePage(exhibition);
                  } else {
                    final seriesIndex = 0; //index - (exhibitionInfoCount - 1);
                    return _getSeriesPreviewPage(seriesIndex, exhibition);
                  }
                default:
                  final seriesIndex = index - (exhibitionInfoCount - 1);
                  return _getSeriesPreviewPage(seriesIndex, exhibition);
              }
            },
          ),
        ),
        if (_currentIndex == 0 || (_currentIndex == 1 && shouldShowNotePage))
          _nextButton(),
        BottomSpacing(),
      ],
    );
  }

  Widget _getSeriesPreviewPage(int seriesIndex, Exhibition exhibition) {
    final series = exhibition.displayableSeries.sorted[seriesIndex];
    final artwork = series.artwork;
    if (artwork == null) {
      return const SizedBox();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: FeralFileArtworkPreview(
        key: Key('feral_file_artwork_preview_${artwork.id}'),
        payload: FeralFileArtworkPreviewPayload(
          artwork:
              artwork.copyWith(series: series.copyWith(exhibition: exhibition)),
        ),
      ),
    );
  }

  void _sendMetricViewExhibition() {
    final exhibition = _exBloc.state.exhibition;
    if (exhibition == null) {
      return;
    }

    final request = _getCastExhibitionRequest(exhibition);
    final data = {
      MetricParameter.exhibitionId: request.exhibitionId,
      MetricParameter.section: request.catalog.metricName,
      if (request.catalog == ExhibitionCatalog.artwork)
        MetricParameter.tokenId: request.catalogId,
    };
    unawaited(injector<MetricClientService>()
        .addEvent(MetricEventName.exhibitionView, data: data));
  }

  Future<void> _stream(Exhibition exhibition) async {
    log.info('onPageChanged: $_currentIndex');
    final displayKey = exhibition.displayKey;
    final lastSelectedDevice =
        _canvasDeviceBloc.state.lastSelectedActiveDeviceForKey(displayKey);
    if (lastSelectedDevice != null) {
      final request = _getCastExhibitionRequest(exhibition);
      log.info('onPageChanged: request: $request');
      final completer = Completer<void>();
      _canvasDeviceBloc.add(
        CanvasDeviceCastExhibitionEvent(lastSelectedDevice, request,
            onDone: completer.complete),
      );
      await completer.future;
    }
  }

  Widget _getPreviewPage(Exhibition exhibition) => Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ExhibitionPreview(
            exhibition: exhibition,
          ),
        ],
      );

  Widget _nextButton() => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: RotatedBox(
          quarterTurns: 3,
          child: IconButton(
            onPressed: () async => _controller.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn),
            constraints: const BoxConstraints(
              maxWidth: 44,
              maxHeight: 44,
              minWidth: 44,
              minHeight: 44,
            ),
            icon: SvgPicture.asset(
              'assets/images/ff_back_dark.svg',
            ),
          ),
        ),
      );

  List<Widget> _resource(Exhibition exhibition) {
    final resources = <Widget>[];
    for (final resource in exhibition.allResources) {
      if (resource is CustomExhibitionNote) {
        resources.add(ExhibitionCustomNote(
          info: resource,
        ));
      }
      if (resource is Post) {
        resources.add(ExhibitionPostView(
          post: resource,
          exhibitionID: exhibition.id,
        ));
      }
    }
    return resources;
  }

  List<Widget> _foreWord(Exhibition exhibition) {
    final foreWords = <Widget>[];
    for (final foreWord in exhibition.foreWord) {
      final id =
          'forework_${exhibition.id}_${exhibition.foreWord.indexOf(foreWord)}';
      foreWords.add(ExhibitionCustomNote(
        info: CustomExhibitionNote(
            id: id,
            title: 'Foreword',
            content: foreWord,
            canReadMore: true,
            readMoreUrl:
                FeralFileHelper.getExhibitionForewordUrl(exhibition.slug)),
      ));
    }
    return foreWords;
  }

  Widget _notePage(Exhibition exhibition) => LayoutBuilder(
        builder: (context, constraints) => Center(
          child: CarouselSlider(
            items: [
              ..._foreWord(exhibition),
              if (exhibition.shouldShowCuratorNote) ...[
                ExhibitionNoteView(
                  exhibition: exhibition,
                ),
              ],
              ..._resource(exhibition),
            ],
            options: CarouselOptions(
              aspectRatio: constraints.maxWidth / constraints.maxHeight,
              viewportFraction: 0.76,
              enableInfiniteScroll: false,
              enlargeCenterPage: true,
              initialPage: _carouselIndex,
              onPageChanged: (index, reason) {
                _carouselIndex = index;
                _stream(exhibition);
              },
            ),
          ),
        ),
      );

  AppBar _getAppBar(BuildContext buildContext, Exhibition? exhibition) =>
      getFFAppBar(
        buildContext,
        onBack: () => Navigator.pop(buildContext),
        action: exhibition != null
            ? FFCastButton(
                displayKey: exhibition.id,
                onDeviceSelected: (device) async {
                  final request = _getCastExhibitionRequest(exhibition);
                  final completer = Completer<void>();
                  _canvasDeviceBloc.add(
                    CanvasDeviceCastExhibitionEvent(device, request,
                        onDone: completer.complete),
                  );
                  await completer.future;
                },
              )
            : null,
      );

  Pair<ExhibitionCatalog, String?> _getCurrentCatalogInfo(
      Exhibition exhibition) {
    ExhibitionCatalog? catalog;
    String? catalogId;
    final shouldShowNotePage = exhibition.shouldShowCuratorNotePage;
    final exhibitionInfoCount = shouldShowNotePage ? 3 : 2;
    switch (_currentIndex) {
      case 0:
        catalog = ExhibitionCatalog.home;
      case 1:
        if (shouldShowNotePage) {
          final foreword = exhibition.foreWord;
          if (_carouselIndex < foreword.length) {
            catalog = ExhibitionCatalog.curatorNote;
          } else if (_carouselIndex == foreword.length) {
            catalog = ExhibitionCatalog.curatorNote;
          } else {
            catalog = ExhibitionCatalog.resource;
            catalogId = exhibition
                .allResources[_carouselIndex - (foreword.length + 1)].id;
          }
        } else {
          catalog = ExhibitionCatalog.artwork;
          final seriesIndex = 0; //_currentIndex - (exhibitionInfoCount - 1);
          catalogId =
              exhibition.displayableSeries.sorted[seriesIndex].artwork?.id;
        }
      default:
        catalog = ExhibitionCatalog.artwork;
        final seriesIndex = _currentIndex - (exhibitionInfoCount - 1);
        catalogId =
            exhibition.displayableSeries.sorted[seriesIndex].artwork?.id;
    }
    return Pair(catalog, catalogId);
  }

  CastExhibitionRequest _getCastExhibitionRequest(Exhibition exhibition) {
    final exhibitionId = exhibition.id;
    final catalogInfo = _getCurrentCatalogInfo(exhibition);
    final catalog = catalogInfo.first;
    final catalogId = catalogInfo.second;
    CastExhibitionRequest request = CastExhibitionRequest(
      exhibitionId: exhibitionId,
      catalog: catalog,
      catalogId: catalogId,
    );
    return request;
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {}
}

class ExhibitionDetailPayload {
  final List<Exhibition> exhibitions;
  final int index;

  const ExhibitionDetailPayload({
    required this.exhibitions,
    required this.index,
  });

  // copyWith function
  ExhibitionDetailPayload copyWith({
    List<Exhibition>? exhibitions,
    int? index,
  }) =>
      ExhibitionDetailPayload(
        exhibitions: exhibitions ?? this.exhibitions,
        index: index ?? this.index,
      );

  // next function: increase index by 1, if index is out of range, return null
  ExhibitionDetailPayload? next() {
    if (index + 1 >= exhibitions.length) {
      return null;
    }
    return copyWith(index: index + 1);
  }
}
