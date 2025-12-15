import 'dart:async';

import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_state.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DailyWorkEvent {}

class GetDailyAssetTokenEvent extends DailyWorkEvent {}

class DailyWorkBloc extends Bloc<DailyWorkEvent, DailiesWorkState> {
  final FeralFileService _feralfileService;

  DailyWorkBloc(this._feralfileService)
      : super(DailiesWorkState(
            assetTokens: [],
            currentDailyToken: null,
            currentArtist: null,
            currentExhibition: null)) {
    on<GetDailyAssetTokenEvent>((event, emit) async {
      final dailiesToken = await _feralfileService.getCurrentDailiesToken();
      final assetTokens = <AssetToken>[];
      AlumniAccount? currentArtist;
      Exhibition? currentExhibition;
      if (assetTokens.isEmpty) {
        return;
      }
      final token = assetTokens.first;
      if (token.isFeralfile) {
        if (token.artistID != null) {
          currentArtist =
              await _feralfileService.getAlumniDetail(token.artistID!);
        }
        currentExhibition = await _feralfileService
            .getExhibitionFromTokenID(dailiesToken!.tokenID);
      }

      emit(DailiesWorkState(
          assetTokens: assetTokens,
          currentDailyToken: dailiesToken,
          currentArtist: currentArtist,
          currentExhibition: currentExhibition));
      unawaited(
          NowDisplayingManager().updateDisplayingNow(addStatusOnError: false));
    });
  }
}
