import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

const double kNowDisplayingHeight = 60;

abstract class NowDisplayingStatus {}

class ConnectionLost implements NowDisplayingStatus {
  ConnectionLost(this.device);

  final BaseDevice device;
}

class DeviceDisconnected implements NowDisplayingStatus {
  DeviceDisconnected(this.device);

  final BaseDevice device;
}

// Now displaying
class NowDisplayingSuccess implements NowDisplayingStatus {
  NowDisplayingSuccess(this.object);

  final NowDisplayingObject object;
}

class NowDisplayingError implements NowDisplayingStatus {
  NowDisplayingError(this.error);

  final Object error;
}

class GettingNowDisplayingObject implements NowDisplayingStatus {}

class ExhibitionDisplaying {
  ExhibitionDisplaying({
    this.exhibition,
    this.catalogId,
    this.catalog,
    this.artwork,
  });

  final Exhibition? exhibition;
  final String? catalogId;
  final ExhibitionCatalog? catalog;
  final Artwork? artwork;
}

class NowDisplayingObject {
  NowDisplayingObject({
    this.assetToken,
    this.exhibitionDisplaying,
    this.dailiesWorkState,
  });

  final AssetToken? assetToken;
  final ExhibitionDisplaying? exhibitionDisplaying;
  final DailiesWorkState? dailiesWorkState;
}

class NowDisplaying extends StatefulWidget {
  const NowDisplaying({super.key});

  @override
  State<NowDisplaying> createState() => _NowDisplayingState();
}

class _NowDisplayingState extends State<NowDisplaying>
    with AfterLayoutMixin<NowDisplaying> {
  final NowDisplayingManager _manager = NowDisplayingManager();
  NowDisplayingStatus? nowDisplayingStatus;

  @override
  void initState() {
    super.initState();
    nowDisplayingStatus = _manager.nowDisplayingStatus;
    _manager.nowDisplayingStream.listen(
      (status) {
        if (mounted) {
          setState(
            () {
              nowDisplayingStatus = status;
            },
          );
        }
      },
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {}

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      listener: (context, state) {},
      builder: (context, state) {
        if (!injector<AuthService>().isBetaTester()) {
          return const SizedBox();
        }
        final nowDisplayingStatus = this.nowDisplayingStatus;
        if (nowDisplayingStatus == null) {
          return const SizedBox();
        }

        switch (nowDisplayingStatus.runtimeType) {
          case DeviceDisconnected:
            return _connectFailedView(context, nowDisplayingStatus);
          case ConnectionLost:
            return _connectionLostView(
              context,
              nowDisplayingStatus,
            );
          case GettingNowDisplayingObject:
            return _gettingNowDisplayingObjectView(context);
          case NowDisplayingError:
            return _getNowDisplayingErrorView(context, nowDisplayingStatus);
          case NowDisplayingSuccess:
            return NowDisplayingSuccessWidget(
              object: (nowDisplayingStatus as NowDisplayingSuccess).object,
            );
          default:
            return const SizedBox();
        }
      },
    );
  }

  Widget _connectFailedView(BuildContext context, NowDisplayingStatus status) {
    final device = (status as DeviceDisconnected).device;
    final deviceName =
        device.name.isNotEmpty == true ? device.name : 'Portal (FF-X1)';
    return NowDisplayingStatusView(
      status: 'Device $deviceName is offline or disconnected.',
    );
  }

  Widget _connectionLostView(
    BuildContext context,
    NowDisplayingStatus status,
  ) {
    final device = (status as ConnectionLost).device;
    final deviceName =
        device.name.isNotEmpty == true ? device.name : 'Portal (FF-X1)';
    return NowDisplayingStatusView(
      status: 'Connection to $deviceName lost.',
    );
  }

  Widget _getNowDisplayingErrorView(
    BuildContext context,
    NowDisplayingStatus nowDisplayingStatus,
  ) {
    final error = (nowDisplayingStatus as NowDisplayingError).error;
    return NowDisplayingStatusView(
      status: 'Error: $error',
    );
  }

  Widget _gettingNowDisplayingObjectView(BuildContext context) {
    return const NowDisplayingStatusView(
      status: 'Getting now displaying object...',
    );
  }
}

class NowDisplayingSuccessWidget extends StatefulWidget {
  const NowDisplayingSuccessWidget({required this.object, super.key});

  final NowDisplayingObject object;

  @override
  State<NowDisplayingSuccessWidget> createState() =>
      _NowDisplayingSuccessWidgetState();
}

class _NowDisplayingSuccessWidgetState
    extends State<NowDisplayingSuccessWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final nowDisplaying = widget.object;
    final assetToken = nowDisplaying.assetToken;
    if (assetToken != null) {
      return _tokenNowDisplayingView(context, assetToken);
    }
    final exhibitionDisplaying = nowDisplaying.exhibitionDisplaying;
    if (exhibitionDisplaying != null) {
      return _exhibitionNowDisplayingView(context, exhibitionDisplaying);
    }
    if (nowDisplaying.dailiesWorkState != null) {
      return _dailyWorkNowDisplayingView(
        context,
        nowDisplaying.dailiesWorkState!,
      );
    }
    return const SizedBox();
  }
}

Widget _tokenNowDisplayingView(BuildContext context, AssetToken assetToken) {
  return GestureDetector(
    child: TokenNowDisplayingView(
      CompactedAssetToken.fromAssetToken(assetToken),
    ),
    onTap: () {
      const pageName = AppRouter.nowDisplayingPage;
      injector<NavigationService>().navigateTo(
        pageName,
      );
    },
  );
}

Widget _dailyWorkNowDisplayingView(
  BuildContext context,
  DailiesWorkState state,
) {
  final assetToken = state.assetTokens.firstOrNull;
  if (assetToken == null) {
    return const SizedBox();
  }
  return GestureDetector(
    child: TokenNowDisplayingView(
      CompactedAssetToken.fromAssetToken(assetToken),
    ),
    onTap: () {
      injector<NavigationService>().navigateTo(
        AppRouter.nowDisplayingPage,
      );
    },
  );
}

Widget _exhibitionNowDisplayingView(
  BuildContext context,
  ExhibitionDisplaying exhibitionDisplaying,
) {
  return GestureDetector(
    child: NowDisplayingExhibitionView(exhibitionDisplaying),
    onTap: () {
      final exhibition = exhibitionDisplaying.exhibition;
      final artwork = exhibitionDisplaying.artwork;
      if (artwork != null) {
        injector<NavigationService>().navigateTo(
          AppRouter.nowDisplayingPage,
        );
      } else if (exhibition != null) {
        injector<NavigationService>().navigateTo(
          AppRouter.nowDisplayingPage,
        );
      }
    },
  );
}

class TokenNowDisplayingView extends StatelessWidget {
  const TokenNowDisplayingView(this.assetToken, {super.key});

  final CompactedAssetToken assetToken;

  IdentityBloc get _identityBloc => injector<IdentityBloc>();

  @override
  Widget build(BuildContext context) {
    _identityBloc.add(GetIdentityEvent([assetToken.artistTitle ?? '']));
    final theme = Theme.of(context);
    return BlocBuilder<IdentityBloc, IdentityState>(
      bloc: _identityBloc,
      builder: (context, state) {
        final artistTitle =
            assetToken.artistTitle?.toIdentityOrMask(state.identityMap) ??
                assetToken.artistTitle;
        return NowDisplayingView(
          onMoreTap: () {
            injector<NavigationService>().showDeviceSettings(
              tokenId: assetToken.id,
              artistName: artistTitle,
            );
          },
          thumbnailBuilder: (context) {
            return AspectRatio(
              aspectRatio: 1,
              child: tokenGalleryThumbnailWidget(
                context,
                assetToken,
                65,
                useHero: false,
              ),
            );
          },
          titleBuilder: (context) {
            return RichText(
              text: TextSpan(
                children: [
                  if (artistTitle != null)
                    TextSpan(
                      text: artistTitle,
                      style: theme.textTheme.ppMori400Black14.copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: AppColor.primaryBlack,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (assetToken.isFeralfile) {
                            injector<NavigationService>()
                                .openFeralFileArtistPage(
                              assetToken.artistID!,
                            );
                          } else {
                            final uri = Uri.parse(
                              assetToken.artistURL?.split(' & ').firstOrNull ??
                                  '',
                            );
                            injector<NavigationService>().openUrl(uri);
                          }
                        },
                    ),
                  if (artistTitle != null)
                    TextSpan(
                      text: ', ',
                      style: theme.textTheme.ppMori400Black14,
                    ),
                  TextSpan(
                    text: assetToken.displayTitle,
                    style: theme.textTheme.ppMori400Black14,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        );
      },
    );
  }
}

class NowDisplayingExhibitionView extends StatelessWidget {
  const NowDisplayingExhibitionView(this.exhibitionDisplaying, {super.key});

  final ExhibitionDisplaying exhibitionDisplaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exhibition = exhibitionDisplaying.exhibition;
    final artwork = exhibitionDisplaying.artwork?.copyWith(
      series: exhibitionDisplaying.artwork?.series
          ?.copyWith(exhibition: exhibition),
    );
    final thumbnailUrl = artwork?.smallThumbnailURL ?? exhibition?.coverUrl;
    final artistAddresses = artwork?.series?.artistAlumni?.addressesList;
    final isUserArtist = artistAddresses != null &&
        injector<AuthService>().isLinkArtist(artistAddresses);
    return NowDisplayingView(
      onMoreTap: artwork?.indexerTokenId != null && isUserArtist
          ? () {
              injector<NavigationService>().openArtistDisplaySetting(
                artwork: artwork,
              );
            }
          : () {
              injector<NavigationService>().showDeviceSettings(
                tokenId: artwork?.indexerTokenId,
                artistName: artwork?.series?.artistAlumni?.alias,
              );
            },
      thumbnailBuilder: (context) {
        final url = thumbnailUrl ?? '';
        if (url.isEmpty) {
          return const SizedBox();
        }
        if (url.isSvgImage()) {
          return SvgPicture.network(
            url,
            height: 65,
            width: 65,
            fit: BoxFit.cover,
            placeholderBuilder: (context) =>
                const GalleryThumbnailPlaceholder(),
          );
        }
        return FFCacheNetworkImage(imageUrl: thumbnailUrl ?? '');
      },
      titleBuilder: (context) {
        if (artwork != null) {
          return RichText(
            text: TextSpan(
              children: [
                if (artwork.series?.artistAlumni?.alias != null)
                  TextSpan(
                    text: artwork.series?.artistAlumni?.alias ?? '',
                    style: theme.textTheme.ppMori400Black14.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: AppColor.primaryBlack,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        injector<NavigationService>().openFeralFileArtistPage(
                          artwork.series?.artistAlumniAccountID ?? '',
                        );
                      },
                  ),
                if (artwork.series?.artistAlumni?.alias != null)
                  TextSpan(
                    text: ', ',
                    style: theme.textTheme.ppMori400Black14,
                  ),
                TextSpan(
                  text: artwork.series?.title ?? '',
                  style: theme.textTheme.ppMori400Black14,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        return Text(
          exhibition?.title ?? '',
          style: theme.textTheme.ppMori400Black14,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class NowDisplayingView extends StatelessWidget {
  const NowDisplayingView({
    required this.thumbnailBuilder,
    required this.titleBuilder,
    this.onMoreTap,
    super.key,
  });

  final Widget Function(BuildContext) thumbnailBuilder;
  final Widget Function(BuildContext) titleBuilder;
  final void Function()? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
      constraints: const BoxConstraints(
        maxHeight: kNowDisplayingHeight,
        minHeight: kNowDisplayingHeight,
      ),
      decoration: BoxDecoration(
        color: AppColor.feralFileLightBlue,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 65),
            child: thumbnailBuilder(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Now Displaying:',
                  style: theme.textTheme.ppMori400Black14,
                  overflow: TextOverflow.ellipsis,
                ),
                Expanded(child: titleBuilder(context)),
              ],
            ),
          ),
          if (onMoreTap != null)
            IconButton(
              onPressed: onMoreTap,
              icon: SvgPicture.asset(
                'assets/images/more_circle.svg',
                width: 22,
                colorFilter: const ColorFilter.mode(
                  AppColor.primaryBlack,
                  BlendMode.srcIn,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NowDisplayingStatusView extends StatelessWidget {
  const NowDisplayingStatusView({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      constraints: const BoxConstraints(
        maxHeight: kNowDisplayingHeight,
        minHeight: kNowDisplayingHeight,
      ),
      decoration: BoxDecoration(
        color: AppColor.auLightGrey,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              status,
              style: Theme.of(context).textTheme.ppMori400Black14,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: SvgPicture.asset(
              'assets/images/closeCycle.svg',
              width: 22,
              height: 22,
            ),
          ),
        ],
      ),
    );
  }
}
