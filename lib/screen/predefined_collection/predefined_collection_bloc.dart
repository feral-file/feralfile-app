import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/dao/dao.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/utils/medium_category.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_screen.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_state.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/medium_category_ext.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PredefinedCollectionBloc
    extends Bloc<PredefinedCollectionEvent, PredefinedCollectionState> {
  final _assetTokenDao = injector.get<AssetTokenDao>();
  final _configurationService = injector.get<ConfigurationService>();

  PredefinedCollectionBloc() : super(PredefinedCollectionInitState()) {
    on<LoadPredefinedCollectionEvent>((event, emit) async {
      emit(
        PredefinedCollectionLoadedState(
          assetTokens: [],
          nftLoadingState: NftLoadingState.loading,
        ),
      );
      List<AssetToken> assetTokens = [];
      if (event.type == PredefinedCollectionType.artist) {
        assetTokens = await _assetTokenDao.findAllAssetTokensByArtistID(
          artistID: event.id ?? '',
        );
      }
      if (event.type == PredefinedCollectionType.medium) {
        final isOther = event.id == MediumCategory.other;
        final mimeTypes = isOther
            ? MediumCategoryExt.getAllMimeType()
            : MediumCategory.mineTypes(event.id ?? '');
        final mediums = isOther
            ? MediumCategoryExt.getAllMediums()
            : MediumCategoryExt.mediums(event.id ?? '');
        assetTokens =
            await _assetTokenDao.findAllAssetTokensByMimeTypesOrMediums(
          mimeTypes: mimeTypes,
          isInMimeTypes: !isOther,
          mediums: mediums,
        );
      }
      final hiddenTokenIDs = _configurationService.getHiddenTokenIDs();
      assetTokens.removeWhere((element) =>
          hiddenTokenIDs.contains(element.id) || (element.balance ?? 0) <= 0);
      final isFilterByTokenTitle =
          event.type == PredefinedCollectionType.medium;
      final tokens = assetTokens
          .map((e) => CompactedAssetToken.fromAssetToken(e))
          .toList()
          .where(
            (element) =>
                !isFilterByTokenTitle ||
                (element.displayTitle
                        ?.toLowerCase()
                        .contains(event.filterStr.toLowerCase()) ??
                    false),
          )
          .toList();
      emit(
        PredefinedCollectionLoadedState(
          assetTokens: tokens,
          nftLoadingState: NftLoadingState.done,
        ),
      );
      return;
    });
  }
}
