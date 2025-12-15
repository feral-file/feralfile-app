import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_list_response.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

class FeaturedWorkView extends StatefulWidget {
  const FeaturedWorkView({
    required this.tokenIDs,
    required this.header,
    super.key,
  });

  final List<String> tokenIDs;
  final Widget? header;

  @override
  State<FeaturedWorkView> createState() => FeaturedWorkViewState();
}

class FeaturedWorkViewState extends State<FeaturedWorkView> {
  List<AssetToken>? _featureTokens;
  final Map<String, Size> _imageSize = {};
  late ScrollController _scrollController;
  late Paging _paging;
  bool _isLoading = false;
  bool _shouldShowControllerBar = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _paging = Paging(offset: 0, limit: 5, total: widget.tokenIDs.length);
    log.info('paging initState: ${_paging.offset}');
    unawaited(_fetchFeaturedTokens(context, _paging));
    _scrollController.addListener(() {
      if (_scrollController.position.pixels + 100 >
          _scrollController.position.maxScrollExtent) {
        unawaited(_loadMoreFeaturedTokens(context, _paging));
      }
    });
  }

  @override
  void didUpdateWidget(covariant FeaturedWorkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.tokenIDs, widget.tokenIDs)) {
      _paging = Paging(offset: 0, limit: 5, total: widget.tokenIDs.length);
      _isLoading = false;
      unawaited(_fetchFeaturedTokens(context, _paging));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _loadingView(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 150),
        child: const LoadingWidget(),
      );

  @override
  Widget build(BuildContext context) => GestureDetector(
        onVerticalDragStart: (details) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.offset);
          }
        },
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.forward) {
              if (!_shouldShowControllerBar) {
                setState(() {
                  _shouldShowControllerBar = true;
                });
              }
            } else if (notification.direction == ScrollDirection.reverse) {
              if (_shouldShowControllerBar) {
                setState(() {
                  _shouldShowControllerBar = false;
                });
              }
            }
            return true;
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.top,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 32,
                ),
              ),
              SliverToBoxAdapter(
                child: widget.header ?? const SizedBox(),
              ),
              if (_featureTokens == null) ...[
                SliverToBoxAdapter(
                  child: _loadingView(context),
                ),
              ] else ...[
                SliverPadding(
                  padding: EdgeInsets.zero,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final token = _featureTokens![index];
                        return BlocBuilder<IdentityBloc, IdentityState>(
                          builder: (context, state) {
                            final artistName =
                                state.identityMap[token.artistName] ??
                                    token.artistName ??
                                    token.artistID ??
                                    '';
                            return GestureDetector(
                              onTap: () {
                                _onTapArtwork(context, token);
                              },
                              child: ColoredBox(
                                color: Colors.transparent,
                                child: Column(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final thumbnailUrl =
                                            token.thumbnailURL ?? '';
                                        final width =
                                            _imageSize[thumbnailUrl]?.width;
                                        final height =
                                            _imageSize[thumbnailUrl]?.height;
                                        double? aspectRatio;
                                        if (width != null &&
                                            height != null &&
                                            height != 0) {
                                          aspectRatio = width / height;
                                        }
                                        return AspectRatio(
                                          aspectRatio: aspectRatio ?? 1.0,
                                          // Provide a default aspect
                                          // ratio if null
                                          child: CachedNetworkImage(
                                            imageUrl: token.thumbnailURL ?? '',
                                            cacheManager:
                                                injector<CacheManager>(),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                            placeholder: (context, url) =>
                                                SizedBox(
                                              height: height,
                                              child: const LoadingWidget(),
                                            ),
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    Image(
                                              image: imageProvider,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _infoHeader(
                                      context,
                                      token,
                                      artistName,
                                      false,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _featureTokens?.length ?? 0,
                    ),
                  ),
                ),
              ],
              // show loading when loading more
              SliverToBoxAdapter(
                child: _isLoading && _paging.offset != 0
                    ? const SizedBox(
                        height: 100,
                        child: LoadingWidget(),
                      )
                    : const SizedBox(),
              ),
              // safe height for bottom
              SliverToBoxAdapter(
                child: Container(
                  height: 80,
                ),
              ),
            ],
          ),
        ),
      );

  Future<List<AssetToken>> _getTokens(
    BuildContext context,
    List<String> tokenIds,
  ) async {
    final bloc = context.read<IdentityBloc>();

    final tokens = await injector<TokensService>().fetchManualTokens(tokenIds);
    final addresses = <String>[];
    for (final token in tokens) {
      addresses
        ..add(token.owner)
        ..add(token.artistName ?? '');
    }
    bloc.add(GetIdentityEvent(addresses));
    await Future.wait(
      tokens.map(
        (token) async {
          try {
            final uri = Uri.tryParse(token.thumbnailURL ?? '');
            if (uri != null) {
              final response = await http.get(uri);

              if (response.statusCode == 200) {
                final bytes = response.bodyBytes;

                // Decode the image
                final image = await decodeImageFromList(bytes);

                // Get width and height
                final width = image.width;
                final height = image.height;
                _imageSize.addEntries([
                  MapEntry(
                    token.thumbnailURL ?? '',
                    Size(width * 1.0, height * 1.0),
                  ),
                ]);
              } else {
                log.info('Failed to load image at ${token.thumbnailURL}');
              }
            }
          } catch (e) {
            log.info('Failed to load image at ${token.thumbnailURL}');
          }
        },
      ),
    );
    return tokens;
  }

  Future<void> _loadMoreFeaturedTokens(
    BuildContext context,
    Paging paging,
  ) async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final tokenIds = widget.tokenIDs.sublist(
        paging.offset,
        min(paging.offset + paging.limit, paging.total),
      );
      if (tokenIds.isEmpty) {
        _isLoading = false;
        return;
      }
      final tokens = await _getTokens(context, tokenIds);
      if (!context.mounted) {
        _isLoading = false;
        return;
      }
      setState(() {
        _featureTokens ??= [];
        _featureTokens!.addAll(tokens);
        _paging = Paging(
          offset: paging.offset + tokens.length,
          limit: paging.limit,
          total: paging.total,
        );

        log.info('feature tokens: ${_featureTokens!.length}');
      });
      _isLoading = false;
    } catch (e) {
      log.info('Error while load more featured work: $e');
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      } else {
        _isLoading = false;
      }
    }
  }

  Future<void> _fetchFeaturedTokens(BuildContext context, Paging paging) async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    final tokenIds =
        widget.tokenIDs.sublist(0, min(paging.limit, paging.total));
    final tokens = await _getTokens(context, tokenIds);
    if (!context.mounted) {
      _isLoading = false;
      return;
    }
    setState(() {
      _featureTokens ??= [];
      _featureTokens!.clear();
      _featureTokens!.addAll(tokens);
      _paging = Paging(
        offset: paging.offset + tokens.length,
        limit: paging.limit,
        total: paging.total,
      );
      _isLoading = false;
      log.info('feature tokens: ${_featureTokens!.length}');
    });
  }

  void _onTapArtwork(BuildContext context, AssetToken token) {
    _gotoArtworkDetails(context, token);
  }

  void _gotoArtworkDetails(BuildContext context, AssetToken token) {
    unawaited(
      Navigator.of(context).pushNamed(
        AppRouter.artworkDetailsPage,
        arguments: ArtworkDetailPayload(
          ArtworkIdentity(
            token.id,
            token.owner,
          ),
          shouldUseLocalCache: false,
        ),
      ),
    );
  }

  Widget _infoHeader(
    BuildContext context,
    AssetToken asset,
    String? artistName,
    bool isViewOnly,
  ) {
    var subTitle = '';
    if (artistName != null && artistName.isNotEmpty) {
      subTitle = artistName;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 5, 40),
      child: Row(
        children: [
          Expanded(
            child: ArtworkDetailsHeader(
              title: asset.displayTitle ?? '',
              onTitleTap: () => _onTapArtwork(context, asset),
              subTitle: subTitle,
              onSubTitleTap: asset.artistID != null && asset.isFeralfile
                  ? () => unawaited(
                        injector<NavigationService>()
                            .openFeralFileArtistPage(asset.artistID!),
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
