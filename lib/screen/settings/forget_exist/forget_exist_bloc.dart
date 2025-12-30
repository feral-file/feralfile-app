//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc_manager.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_state.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ForgetExistBloc extends AuBloc<ForgetExistEvent, ForgetExistState> {
  ForgetExistBloc(
    this._indexerDatabase,
    this._configurationService,
  ) : super(ForgetExistState(false, null)) {
    on<UpdateCheckEvent>((event, emit) async {
      emit(ForgetExistState(event.isChecked, state.isProcessing));
    });

    on<ConfirmForgetExistEvent>((event, emit) async {
      emit(ForgetExistState(state.isChecked, true));
      // remove all local data
      _indexerDatabase.clearAll();
      await _configurationService.removeAll();
      await injector<CacheManager>().emptyCache();
      await DefaultCacheManager().emptyCache();
      await injector<NftTokensService>().purgeCachedGallery();
      memoryValues = MemoryValues();

      // delete dp1 data: playlists, channels;
      await injector<UserDp1PlaylistService>().clearData();
      // remove all local settings data
      unawaited(injector<AppDataManager>().deleteAll());

      await injector<CustomerSupportService>().clear();
      await injector<IdentityBloc>().clear();
      injector<UserAllOwnCollectionBloc>().add(ClearDataEvent());
      injector<CanvasDeviceBloc>().clear();
      await BluetoothDeviceManager().resetDevice();
      await CanvasNotificationManager().disconnectAll();

      await FileLogger.clear();
      await SentryBreadcrumbLogger.clear();
      await injector<PlaylistDetailsBlocManager>().close();

      emit(ForgetExistState(state.isChecked, false));
    });
  }

  final IndexerDatabaseAbstract _indexerDatabase;
  final ConfigurationService _configurationService;
}
