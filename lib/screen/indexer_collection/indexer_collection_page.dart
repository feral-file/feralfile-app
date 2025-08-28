import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/indexer_collection/indexer_collection_bloc.dart';
import 'package:autonomy_flutter/screen/indexer_collection/indexer_collection_state.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:autonomy_flutter/view/user_collection_title_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:sentry/sentry.dart';

class IndexerCollectionPage extends StatefulWidget {
  const IndexerCollectionPage({required this.payload, super.key});

  final IndexerCollectionPagePayload payload;

  @override
  State<IndexerCollectionPage> createState() => _IndexerCollectionPageState();
}

class _IndexerCollectionPageState extends State<IndexerCollectionPage> {
  late final IndexerCollectionBloc _indexerCollectionBloc;
  static const _padding = 14.0;
  static const _axisSpacing = 5.0;
  PagingState<int, AssetToken> _pageState = PagingState<int, AssetToken>();

  @override
  void initState() {
    super.initState();
    _indexerCollectionBloc = context.read<IndexerCollectionBloc>();
    _indexerCollectionBloc
        .add(IndexerCollectionGetCollectionEvent(widget.payload.collection.id));
  }

  Future<void> _fetchPage(BuildContext context, int pageKey) async {
    try {
      final newItems =
          await injector<NftIndexerService>().getCollectionListToken(
        widget.payload.collection.id,
      );
    } catch (error) {
      log.info('Error fetching series page: $error');
      unawaited(Sentry.captureException(error));
    }
  }

  Future<void> _fetchNextPage() async {
    if (_pageState.isLoading) return;

    setState(() {
      _pageState = _pageState.copyWith(isLoading: true, error: null);
    });

    try {
      final newKey = (_pageState.keys?.last ?? 0) + 1;
      final newItems = await injector<NftIndexerService>()
          .getCollectionListToken(widget.payload.collection.id);
      final isLastPage = true;

      setState(() {
        _pageState = _pageState.copyWith(
          pages: [...?_pageState.pages, newItems],
          keys: [...?_pageState.keys, newKey],
          hasNextPage: !isLastPage,
          isLoading: false,
        );
      });
    } catch (error) {
      log.info('Error fetching collection page: $error');
      unawaited(Sentry.captureException(error));
      setState(() {
        _pageState = _pageState.copyWith(
          error: error,
          isLoading: false,
        );
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<IndexerCollectionBloc, IndexerCollectionState>(
        builder: (context, state) => Scaffold(
            appBar: _getAppBar(context, widget.payload.collection),
            backgroundColor: AppColor.primaryBlack,
            body: _body(context, state.assetTokens, state.thumbnailRatio)),
        listener: (context, state) {},
      );

  AppBar _getAppBar(BuildContext buildContext, UserCollection? collection) =>
      getFFAppBar(
        buildContext,
        onBack: () => Navigator.pop(buildContext),
        title: collection == null
            ? const SizedBox()
            : IndexerCollectionTitleView(
                collection: collection,
                artist: widget.payload.artist,
                crossAxisAlignment: CrossAxisAlignment.center),
      );

  Widget _body(BuildContext context, List<AssetToken>? listAssetToken,
      double? thumbnailRatio) {
    if (listAssetToken == null) {
      return _loadingIndicator();
    }
    return _artworkSliverGrid(context, listAssetToken, thumbnailRatio ?? 1);
  }

  Widget _loadingIndicator() => Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: loadingIndicator(valueColor: AppColor.auGrey),
        ),
      );

  Widget _artworkSliverGrid(
      BuildContext context, List<AssetToken> assetToken, double ratio) {
    final cacheWidth =
        (MediaQuery.sizeOf(context).width - _padding * 2 - _axisSpacing * 2) ~/
            3;
    final cacheHeight = (cacheWidth / ratio).toInt();
    return Padding(
      padding:
          const EdgeInsets.only(left: _padding, right: _padding, bottom: 20),
      child: CustomScrollView(
        slivers: [
          PagedSliverGrid<int, AssetToken>(
            state: _pageState,
            fetchNextPage: _fetchNextPage,
            showNewPageErrorIndicatorAsGridChild: false,
            showNewPageProgressIndicatorAsGridChild: false,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisSpacing: _axisSpacing,
              mainAxisSpacing: _axisSpacing,
              crossAxisCount: 3,
              childAspectRatio: ratio,
            ),
            builderDelegate: PagedChildBuilderDelegate<AssetToken>(
              itemBuilder: (context, artwork, index) => FFArtworkThumbnailView(
                url: artwork.galleryThumbnailURL ?? '',
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                onTap: () async {
                  await Navigator.of(context).pushNamed(
                    AppRouter.artworkDetailsPage,
                    arguments: ArtworkDetailPayload(
                      ArtworkIdentity(
                        artwork.id,
                        artwork.owner,
                      ),
                      useIndexer: true,
                    ),
                  );
                },
              ),
              newPageProgressIndicatorBuilder: (context) => _loadingIndicator(),
              firstPageErrorIndicatorBuilder: (context) => const SizedBox(),
              newPageErrorIndicatorBuilder: (context) => const SizedBox(),
            ),
          )
        ],
      ),
    );
  }
}

class IndexerCollectionPagePayload {
  final UserCollection collection;
  final AlumniAccount? artist;

  const IndexerCollectionPagePayload({
    required this.collection,
    this.artist,
  });
}
