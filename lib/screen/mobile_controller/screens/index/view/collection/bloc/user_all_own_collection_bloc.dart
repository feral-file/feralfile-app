import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'user_all_own_collection_event.dart';
part 'user_all_own_collection_state.dart';

class UserAllOwnCollectionBloc
    extends Bloc<UserAllOwnCollectionEvent, UserAllOwnCollectionState> {
  UserAllOwnCollectionBloc(this._indexerService)
      : super(const UserAllOwnCollectionState()) {
    on<LoadDynamicQueryEvent>(_onLoadDynamicQuery);
  }

  final NftIndexerService _indexerService;

  Future<void> _onLoadDynamicQuery(
    LoadDynamicQueryEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      emit(state.copyWith(status: UserAllOwnCollectionStatus.loading));
      final owners = event.dynamicQuery.params.owners;
      final assets = await _indexerService.getNftTokens(
        QueryListTokensRequest(owners: owners, size: 100),
      );
      emit(
        state.copyWith(
          status: UserAllOwnCollectionStatus.loaded,
          assetTokens: assets,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
