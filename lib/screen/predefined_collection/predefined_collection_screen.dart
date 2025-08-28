import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/models/predefined_collection_model.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_bloc.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_state.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/medium_category_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PredefinedCollectionType { artist, medium }

class PredefinedCollectionScreenPayload {
  final PredefinedCollectionType type;
  final PredefinedCollectionModel predefinedCollection;
  final String filterStr;

  const PredefinedCollectionScreenPayload(
      {required this.type,
      required this.predefinedCollection,
      required this.filterStr});
}

class PredefinedCollectionScreen extends StatefulWidget {
  final PredefinedCollectionScreenPayload payload;

  const PredefinedCollectionScreen({required this.payload, super.key});

  @override
  State<PredefinedCollectionScreen> createState() =>
      _PredefinedCollectionScreenState();
}

class _PredefinedCollectionScreenState
    extends State<PredefinedCollectionScreen> {
  final _bloc = injector.get<PredefinedCollectionBloc>();

  @override
  void initState() {
    super.initState();
    _bloc.add(LoadPredefinedCollectionEvent(
        type: widget.payload.type,
        id: widget.payload.predefinedCollection.id,
        filterStr: widget.payload.filterStr));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColor.primaryBlack,
        body: BlocConsumer<PredefinedCollectionBloc, PredefinedCollectionState>(
          bloc: _bloc,
          builder: (context, state) {
            if (state is PredefinedCollectionInitState) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: CircularProgressIndicator());
          },
          listener: (context, state) {
            if (state is PredefinedCollectionLoadedState &&
                state.nftLoadingState == NftLoadingState.done) {
              final id = widget.payload.predefinedCollection.id;
              final name = widget.payload.predefinedCollection.name;
              final tokenIDs = state.assetTokens?.map((e) => e.id).toList();
              final playlist = PlayListModel(
                id: id,
                name: name,
                tokenIDs: tokenIDs ?? [],
              );
              final predefinedCollectionType = widget.payload.type;
              final icon =
                  predefinedCollectionType == PredefinedCollectionType.medium
                      ? SvgPicture.asset(MediumCategoryExt.icon(id),
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                              AppColor.white, BlendMode.srcIn))
                      : null;
              final collectionType =
                  predefinedCollectionType == PredefinedCollectionType.medium
                      ? CollectionType.medium
                      : CollectionType.artist;
              unawaited(Navigator.of(context).pushReplacementNamed(
                  AppRouter.viewPlayListPage,
                  arguments: ViewPlaylistScreenPayload(
                      playListModel: playlist,
                      titleIcon: icon,
                      collectionType: collectionType)));
            }
          },
        ),
      );
}
