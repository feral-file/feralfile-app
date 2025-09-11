import 'dart:async';

import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/view/ff_title_row.dart';
import 'package:flutter/material.dart';

class ExhibitionCard extends StatelessWidget {
  const ExhibitionCard({
    required this.exhibition,
    required this.viewableExhibitions,
    this.horizontalMargin,
    this.width,
    this.height,
    super.key,
    this.onExhibitionTap,
  });

  final Exhibition exhibition;
  final List<Exhibition> viewableExhibitions;
  final double? horizontalMargin;
  final double? width;
  final double? height;
  final FutureOr<void> Function(List<Exhibition> exhibitions, int index)?
      onExhibitionTap;

  @override
  Widget build(BuildContext context) {
    final index = viewableExhibitions.indexOf(exhibition);
    return FFTitleRow(
      onTap: () async => _onExhibitionTap(context, viewableExhibitions, index),
      title: exhibition.title,
    );
  }

  Future<void> _onExhibitionTap(
    BuildContext context,
    List<Exhibition> viewableExhibitions,
    int index,
  ) async {
    if (index >= 0) {
      if (onExhibitionTap != null) {
        await onExhibitionTap!(viewableExhibitions, index);
      } else {
        await Navigator.of(context).pushNamed(
          AppRouter.exhibitionDetailPage,
          arguments: ExhibitionDetailPayload(
            exhibitions: viewableExhibitions,
            index: index,
          ),
        );
      }
    }
  }
}
