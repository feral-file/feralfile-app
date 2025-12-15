import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/additional_data/additional_data.dart';
import 'package:autonomy_flutter/model/dailies.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_page.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum DailyCTATarget {
  dailyPage,
  viewDailySeries,
  viewDailyExhibition,
  viewDailyArtist,
  displayDailyOnTV,
  ;

  @override
  String toString() {
    switch (this) {
      case DailyCTATarget.dailyPage:
        return 'daily_page';
      case DailyCTATarget.viewDailySeries:
        return 'view_daily_series';
      case DailyCTATarget.viewDailyExhibition:
        return 'view_daily_exhibition';
      case DailyCTATarget.viewDailyArtist:
        return 'view_daily_artist';
      case DailyCTATarget.displayDailyOnTV:
        return 'display_daily_on_tv';
    }
  }

  static DailyCTATarget? fromString(String? value) {
    switch (value) {
      case 'daily_page':
        return DailyCTATarget.dailyPage;
      case 'view_daily_series':
        return DailyCTATarget.viewDailySeries;
      case 'view_daily_exhibition':
        return DailyCTATarget.viewDailyExhibition;
      case 'view_daily_artist':
        return DailyCTATarget.viewDailyArtist;
      case 'display_daily_on_tv':
        return DailyCTATarget.displayDailyOnTV;
      default:
        return null;
    }
  }
}

class DailyNotificationData extends AdditionalData {
  final _feralFileService = injector<FeralFileService>();
  final _dailyWorkBloc = injector<DailyWorkBloc>();
  final DailyCTATarget? dailyCTATarget;

  DailyNotificationData({
    required super.notificationType,
    super.announcementContentId,
    super.cta,
    this.dailyCTATarget,
  });

  @override
  bool get isTappable => true;

  @override
  Future<void> handleTap(BuildContext context) async {
    log.info('DailyNotificationData: handle tap');

    if (cta == null) {
      _logAndSendSentryForNullData('cta');
      return;
    }

    bool isDailyTokenAvailable = await prepareAndDidSuccess();
    if (!isDailyTokenAvailable) {
      _logAndSendSentryForNullData('dailyToken');
      return;
    }
    final dailyToken = _dailyWorkBloc.state.currentDailyToken;

    if (dailyCTATarget == null) {
      log.info('Invalid daily cta target ${cta!.navigationRoute}');
      return;
    }

    switch (dailyCTATarget!) {
      case DailyCTATarget.dailyPage:
        return;
      case DailyCTATarget.viewDailySeries:
        final artwork = dailyToken!.artwork;
        if (artwork == null) {
          _logAndSendSentryForNullData('artwork');
          return;
        }
        final series = await _feralFileService.getSeries(artwork.seriesID);
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).pushNamed(
          AppRouter.feralFileSeriesPage,
          arguments: FeralFileSeriesPagePayload(
            seriesId: artwork.seriesID,
            exhibitionId: series.exhibitionID,
          ),
        );
      case DailyCTATarget.viewDailyExhibition:
        final artwork = dailyToken!.artwork;
        if (artwork == null) {
          _logAndSendSentryForNullData('artwork');
          return;
        }
        final series = await _feralFileService.getSeries(artwork.seriesID);
        final exhibition = series.exhibition;
        if (exhibition == null) {
          _logAndSendSentryForNullData('exhibition');
          return;
        }
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).pushNamed(
          AppRouter.exhibitionDetailPage,
          arguments:
              ExhibitionDetailPayload(exhibitions: [exhibition], index: 0),
        );
      case DailyCTATarget.viewDailyArtist:
        final artistID = _dailyWorkBloc.state.assetTokens.firstOrNull?.artistID;

        if (artistID == null) {
          _logAndSendSentryForNullData('artistID');
          return;
        }
        await injector<NavigationService>().openFeralFileArtistPage(artistID);
      case DailyCTATarget.displayDailyOnTV:
        return;
    }
  }

  void _logAndSendSentryForNullData(String data) {
    log.warning('DailyNotificationData: $data is null');
    unawaited(Sentry.captureMessage('DailyNotificationData: $data is null'));
  }

  @override
  Future<bool> prepareAndDidSuccess() async {
    DailyToken? dailyToken = _dailyWorkBloc.state.currentDailyToken;
    if (dailyToken == null) {
      log.warning('DailyNotificationData: dailyToken is null, retrying');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      dailyToken = _dailyWorkBloc.state.currentDailyToken;
    }
    if (dailyToken == null) {
      log.warning('DailyNotificationData: dailyToken is null');
      unawaited(
          Sentry.captureMessage('DailyNotificationData: dailyToken is null'));
      return false;
    }
    return true;
  }
}
