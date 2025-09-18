// WidgetbookUseCase seriesView() {
//   return WidgetbookUseCase(
//     name: 'Series View',
//     builder: (context) => SeriesView(
//       series: MockFFSeriesData.listSeries,
//       userCollections: const [],
//       exploreBar: const SizedBox(),
//       header: const SizedBox.shrink(),
//     ),
//   );
// }

import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_page.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_state.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview_detail/preview_detail_widget.dart';
import 'package:autonomy_flutter/screen/detail/royalty/royalty_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/daily_progress_bar.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_injector.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/index.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_asset_token.dart';
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookUseCase progressBar() {
  return WidgetbookUseCase(
      name: 'Progress Bar',
      builder: (context) {
        final progress = context.knobs.double
            .slider(label: 'Progress', initialValue: 0.5, min: 0.0, max: 1.0);
        return ProgressBar(progress: progress);
      });
}

// DailyProgressBar
WidgetbookUseCase dailyProgressBar() {
  return WidgetbookUseCase(
    name: 'Daily Progress Bar',
    builder: (context) {
      final remainingDuration = context.knobs.duration(
          label: 'Remaining Duration', initialValue: Duration(hours: 1));
      final totalDuration = context.knobs
          .duration(label: 'Total Duration', initialValue: Duration(hours: 2));
      final time = context.knobs.dateTime(
        label: 'Time',
        initialValue: DateTime.now(),
        start: DateTime.now().subtract(Duration(hours: 2)),
        end: DateTime.now().add(Duration(hours: 2)),
      );
      return DailyProgressBar(
        remainingDuration: remainingDuration,
        totalDuration: totalDuration,
      );
    },
  );
}

// ArtworkPreviewWidget
WidgetbookUseCase artworkPreviewWidget() {
  return WidgetbookUseCase(
    name: 'Artwork Preview Widget',
    builder: (context) {
      // This is a placeholder for the actual ArtworkIdentity
      final title = context.knobs.list(label: 'Asset Token', options: [
        ...MockAssetToken.all.map((token) => token.displayTitle),
      ]);
      final assetToken = MockAssetToken.all.firstWhere(
        (token) => token.displayTitle == title,
        orElse: () => MockAssetToken.all.first,
      );
      final identity = ArtworkIdentity(
        assetToken.id,
        assetToken.owner,
      );
      return ArtworkPreviewWidget(
        identity: identity,
        onLoaded: ({webViewController, time}) async {
          // Mock loading logic
          print('Artwork loaded with time: $time');
        },
        onDispose: ({time}) async {
          // Mock dispose logic
          print('Artwork disposed with time: $time');
        },
      );
    },
  );
}

//DailyDetails
WidgetbookUseCase dailyDetails() {
  return WidgetbookUseCase(
    name: 'Daily Details',
    builder: (context) {
      final title = context.knobs.list(
        label: 'Asset Token',
        options: [
          ...MockAssetToken.all.map((token) => token.displayTitle),
        ],
      );
      final assetToken = MockAssetToken.all.firstWhere(
        (token) => token.displayTitle == title,
        orElse: () => MockAssetToken.all.first,
      );

      final currentExhibitionTitle = context.knobs.list(
          label: 'Exhibition',
          options:
              MockExhibitionData.listExhibition.map((e) => e.title).toList());
      final currentExhibition = MockExhibitionData.listExhibition.firstWhere(
        (e) => e.title == currentExhibitionTitle,
        orElse: () => MockExhibitionData.listExhibition.first,
      );

      final currentArtsitTitle = context.knobs.list(
          label: 'Artist',
          options: MockAlumniData.listAll.map((e) => e.fullName).toList());
      final currentArtsit = MockAlumniData.listAll.firstWhere(
        (e) => e.fullName == currentArtsitTitle,
        orElse: () => MockAlumniData.listAll.first,
      );
      final state = DailiesWorkState(
        assetTokens: [assetToken],
        currentDailyToken: null,
        currentArtist: currentArtsit, // Mock artist data
        currentExhibition: currentExhibition, // Mock exhibition data
      );
      return MultiBlocProvider(providers: [
        BlocProvider<IdentityBloc>.value(
          value: MockInjector.get<IdentityBloc>(),
        ),
        BlocProvider<RoyaltyBloc>(
          create: (context) => RoyaltyBloc(MockInjector.get()),
        )
      ], child: DailyDetails(state: state));
    },
  );
}

//FFCastButton

WidgetbookUseCase ffCastButton() {
  return WidgetbookUseCase(
    name: 'FF Cast Button',
    builder: (context) {
      final text = context.knobs.stringOrNull(
        label: 'Button Text',
        initialValue: 'Cast to Device',
      );
      return MultiBlocProvider(
          providers: [
            BlocProvider<CanvasDeviceBloc>.value(
              value: MockInjector.get<CanvasDeviceBloc>(),
            ),
            BlocProvider<SubscriptionBloc>.value(
              value: MockInjector.get<SubscriptionBloc>(),
            ),
          ],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: FFCastButton(
                  text: text,
                  shouldCheckSubscription: false,
                ),
              ),
            ],
          ));
    },
  );
}

// ArtworkDetailsHeader
WidgetbookUseCase artworkDetailsHeader() {
  return WidgetbookUseCase(
    name: 'Artwork Details Header',
    builder: (context) {
      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'Artwork Title',
      );
      final subtitle = context.knobs.string(
        label: 'Artist',
        initialValue: 'Artist Name',
      );

      final isHiddenArtist = context.knobs.boolean(
        label: 'Hide Artist',
        initialValue: false,
      );

      final color = context.knobs.color(
        label: 'Color',
        initialValue: AppColor.white,
      );
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Center(
                child: Expanded(
                  child: ArtworkDetailsHeader(
                    title: title,
                    subTitle: subtitle,
                    hideArtist: isHiddenArtist,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
