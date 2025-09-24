import 'dart:async';

import 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc.dart';
import 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc_event.dart';

abstract class ClientTokenService {
  NftCollectionBloc get nftBloc;

  Future<void> refreshTokens({
    bool checkPendingToken = false,
    bool syncAddresses = false,
  });
}

class ClientTokenServiceImpl implements ClientTokenService {
  ClientTokenServiceImpl(
    this._nftBloc,
  );

  final NftCollectionBloc _nftBloc;

  @override
  NftCollectionBloc get nftBloc => _nftBloc;

  @override
  Future<void> refreshTokens({
    bool checkPendingToken = false,
    bool syncAddresses = false,
  }) async {
    _nftBloc.add(RefreshNftCollectionByOwners());
  }
}
