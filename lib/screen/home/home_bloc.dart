//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/home/home_state.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:in_app_review/in_app_review.dart';

class HomeBloc extends AuBloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeState()) {
    on<CheckReviewAppEvent>((event, emit) async {
      try {
        final config = injector<ConfigurationService>();
        final lastRemind = config.lastRemindReviewDate();
        final countOpenApp = config.countOpenApp() ?? 0;

        if (lastRemind == null) {
          await config
              .setLastRemindReviewDate(DateTime.now().toIso8601String());
          return;
        }

        final isRemind = DateTime.parse(lastRemind)
            .add(Constants.durationToReview)
            .isBefore(DateTime.now());

        if (!isRemind) {
          return;
        }

        if (countOpenApp < Constants.minCountToReview) {
          await config
              .setLastRemindReviewDate(DateTime.now().toIso8601String());
          await config.setCountOpenApp(0);
          return;
        }

        final inAppReview = InAppReview.instance;
        final isAvailable = await inAppReview.isAvailable();

        if (!isAvailable) {
          return;
        }

        await Future.delayed(const Duration(seconds: 15), () {
          inAppReview.requestReview();
          config
            ..setLastRemindReviewDate(DateTime.now().toIso8601String())
            ..setCountOpenApp(0);
        });
      } catch (e) {
        log.info('[Home bloc] $e');
      }
    });
  }
}
