import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_intent.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/feral_file_helper.dart';
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
    _exBloc.add(
      GetExhibitionDetailEvent(
        widget.payload.exhibitions[widget.payload.index].id,
      ),
    );
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
      );

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
                    const seriesIndex = 0; //index - (exhibitionInfoCount - 1);
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
        const BottomSpacing(),
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
      padding: EdgeInsets.zero,
      child: FeralFileArtworkPreview(
        key: Key('feral_file_artwork_preview_${artwork.id}'),
        payload: FeralFileArtworkPreviewPayload(
          artwork:
              artwork.copyWith(series: series.copyWith(exhibition: exhibition)),
        ),
      ),
    );
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
              curve: Curves.easeIn,
            ),
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
        resources.add(
          ExhibitionCustomNote(
            info: resource,
          ),
        );
      }
      if (resource is Post) {
        resources.add(
          ExhibitionPostView(
            post: resource,
            exhibitionID: exhibition.id,
          ),
        );
      }
    }
    return resources;
  }

  List<Widget> _foreWord(Exhibition exhibition) {
    final foreWords = <Widget>[];
    for (final foreWord in exhibition.foreWord) {
      final id =
          'forework_${exhibition.id}_${exhibition.foreWord.indexOf(foreWord)}';
      foreWords.add(
        ExhibitionCustomNote(
          info: CustomExhibitionNote(
            id: id,
            title: 'Foreword',
            content: foreWord,
            canReadMore: true,
            readMoreUrl:
                FeralFileHelper.getExhibitionForewordUrl(exhibition.slug),
          ),
        ),
      );
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
              },
            ),
          ),
        ),
      );

  AppBar _getAppBar(BuildContext buildContext, Exhibition? exhibition) {
    final shouldShowCastButton = exhibition != null &&
        (_currentIndex != 0 &&
            !(_currentIndex == 1 && exhibition.shouldShowCuratorNotePage));
    return getFFAppBar(
      buildContext,
      onBack: () => Navigator.pop(buildContext),
      action: shouldShowCastButton
          ? FFCastButton(
              // displayKey: exhibition.id,
              onDeviceSelected: (device) async {
                final shouldShowNotePage = exhibition.shouldShowCuratorNotePage;
                final exhibitionInfoCount = shouldShowNotePage ? 3 : 2;
                final index = _currentIndex - (exhibitionInfoCount - 1);
                final artworks = exhibition.displayableSeries.sorted
                    .map(
                      (e) => e.artwork?.copyWith(
                        series: e.copyWith(exhibition: exhibition),
                      ),
                    )
                    .where((e) => e != null)
                    .map((e) => e!)
                    .toList();
                if (artworks.isEmpty) {
                  return;
                }
                // Cycle artworks so the artwork at current index becomes first
                final startIndex = index.clamp(0, artworks.length - 1);
                final rotatedArtworks = [
                  ...artworks.sublist(startIndex),
                  ...artworks.sublist(0, startIndex),
                ];
                final dp1items = rotatedArtworks
                    .map((e) => e.dp1Item)
                    .where((e) => e != null)
                    .map((e) => e!)
                    .toList();
                if (dp1items.isEmpty) {
                  return;
                }

                final playlist = DP1CallExtension.fromItems(items: dp1items);
                final completer = Completer<void>();
                _canvasDeviceBloc.add(
                  CanvasDeviceCastDP1PlaylistEvent(
                    device: device,
                    playlist: playlist,
                    usingUrl: false,
                    intent: DP1Intent.displayNow(),
                    onDoneCallback: completer.complete,
                  ),
                );
                await completer.future;
              },
            )
          : null,
    );
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {}
}

class ExhibitionDetailPayload {
  const ExhibitionDetailPayload({
    required this.exhibitions,
    required this.index,
  });
  final List<Exhibition> exhibitions;
  final int index;

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
