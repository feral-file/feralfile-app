import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_page.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

class NowDisplayingPage extends StatefulWidget {
  const NowDisplayingPage({super.key});

  @override
  State<NowDisplayingPage> createState() => NowDisplayingPageState();
}

class NowDisplayingPageState extends State<NowDisplayingPage> {
  final NowDisplayingManager _manager = NowDisplayingManager();
  StreamSubscription<dynamic>? _nowDisplayingSubscription;
  NowDisplayingStatus? nowDisplayingStatus;

  @override
  void initState() {
    super.initState();
    nowDisplayingStatus = _manager.nowDisplayingStatus;
    _onUpdateNowDisplayingStatus(nowDisplayingStatus);
    _nowDisplayingSubscription = _manager.nowDisplayingStream.listen(
      (nowDisplayingObject) {
        if (mounted) {
          setState(
            () {
              nowDisplayingStatus = nowDisplayingObject;
            },
          );
          _onUpdateNowDisplayingStatus(nowDisplayingObject);
        }
      },
    );
  }

  @override
  void dispose() {
    _nowDisplayingSubscription?.cancel();
    super.dispose();
  }

  void _onUpdateNowDisplayingStatus(NowDisplayingStatus? nowDisplayingStatus) {
    if (nowDisplayingStatus is! NowDisplayingSuccess) {
      return;
    }

    final object = nowDisplayingStatus.object;

    if (object is DP1NowDisplayingObject) {
      final assetToken = object.assetToken;
      _onUpdateAssetToken(assetToken);
    }
  }

  void _onUpdateAssetToken(AssetToken assetToken) {
    final artworkIdentity = ArtworkIdentity(
      assetToken.id,
      assetToken.owner,
    );
    context.read<ArtworkDetailBloc>().add(
          ArtworkDetailGetInfoEvent(
            artworkIdentity,
            withArtwork: true,
            useIndexer: true,
          ),
        );
  }

  String? getTokenId(NowDisplayingStatus? nowDisplayingStatus) {
    if (nowDisplayingStatus == null ||
        nowDisplayingStatus is! NowDisplayingSuccess) {
      return null;
    }
    final object = nowDisplayingStatus.object;
    if (object is DP1NowDisplayingObject) {
      return object.playlistItem.indexId;
    }

    return null;
  }

  String? getArtistName(NowDisplayingStatus? nowDisplayingStatus) {
    if (nowDisplayingStatus == null ||
        nowDisplayingStatus is! NowDisplayingSuccess) {
      return null;
    }

    final object = nowDisplayingStatus.object;
    if (object is DP1NowDisplayingObject) {
      return object.playlistItem.title;
    }

    return null;
  }

  Artwork? getArtwork(NowDisplayingStatus? nowDisplayingStatus) {
    return null;
  }

  bool get isArtist {
    final artwork = getArtwork(nowDisplayingStatus);
    if (artwork == null) {
      return false;
    }
    final artistAddresses = artwork.series?.artistAlumni?.addressesList;
    final isUserArtist = artistAddresses != null &&
        injector<AuthService>().isLinkArtist(artistAddresses);
    return isUserArtist;
  }

  @override
  Widget build(BuildContext context) {
    final tokenId = getTokenId(nowDisplayingStatus);
    final artistName = getArtistName(nowDisplayingStatus);
    return Scaffold(
      appBar: getBackAppBar(
        context,
        onBack: () {
          Navigator.of(context).pop();
        },
        title: 'now_displaying'.tr(),
        isWhite: false,
        icon: SvgPicture.asset(
          'assets/images/more_circle.svg',
          width: 22,
          colorFilter: const ColorFilter.mode(
            AppColor.white,
            BlendMode.srcIn,
          ),
        ),
        action: tokenId != null && isArtist
            ? () => injector<NavigationService>().openArtistDisplaySetting(
                  artwork: getArtwork(nowDisplayingStatus),
                )
            : () => injector<NavigationService>().showDeviceSettings(
                  tokenId: tokenId,
                  artistName: artistName,
                ),
      ),
      backgroundColor: AppColor.primaryBlack,
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    if (nowDisplayingStatus == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColor.white),
      );
    }
    switch (nowDisplayingStatus!.runtimeType) {
      case NowDisplayingSuccess:
        final object = (nowDisplayingStatus! as NowDisplayingSuccess).object;
        if (object is DP1NowDisplayingObject) {
          return _tokenNowDisplaying(context);
        }
        return const SizedBox();
      case DeviceDisconnected:
        return Text(
          'Device disconnected',
          style: theme.textTheme.ppMori400White14,
        );
      case ConnectionLost:
        return Text('Connection lost', style: theme.textTheme.ppMori400White14);
      default:
        return Text('Unknown state', style: theme.textTheme.ppMori400White14);
    }
  }

  Widget _tokenNowDisplaying(BuildContext context) {
    Theme.of(context);
    return BlocConsumer<ArtworkDetailBloc, ArtworkDetailState>(
      listener: (context, state) {
        final identitiesList = state.provenances.map((e) => e.owner).toList();
        if (state.assetToken?.artistName != null &&
            state.assetToken!.artistName!.length > 20) {
          identitiesList.add(state.assetToken!.artistName!);
        }

        identitiesList.add(state.assetToken?.owner ?? '');
        context.read<IdentityBloc>().add(GetIdentityEvent(identitiesList));
      },
      builder: (context, state) {
        final assetToken = state.assetToken;
        if (assetToken == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        return TokenNowDisplaying(
          assetToken: assetToken,
        );
      },
    );
  }
}

Widget infoHeader(
  BuildContext context,
  AssetToken asset,
  String? artistName,
) {
  var subTitle = '';
  if (artistName != null && artistName.isNotEmpty) {
    subTitle = artistName;
  }
  return Padding(
    padding: const EdgeInsets.fromLTRB(15, 15, 5, 20),
    child: Row(
      children: [
        Expanded(
          child: ArtworkDetailsHeader(
            title: asset.displayTitle ?? '',
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

class TokenNowDisplaying extends StatefulWidget {
  const TokenNowDisplaying({
    required this.assetToken,
    super.key,
    this.exhibition,
  });

  @override
  State<TokenNowDisplaying> createState() => _TokenNowDisplayingState();

  final AssetToken assetToken;
  final Exhibition? exhibition;
}

class _TokenNowDisplayingState extends State<TokenNowDisplaying> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetToken = widget.assetToken;
    final identityState = context.watch<IdentityBloc>().state;
    final artistName =
        assetToken.artistName?.toIdentityOrMask(identityState.identityMap);
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 30,
          ),
        ),
        SliverToBoxAdapter(
          child: _tokenPreview(context, assetToken),
        ),
        SliverToBoxAdapter(
          child: infoHeader(context, assetToken, artistName),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HtmlWidget(
              customStylesBuilder: auHtmlStyle,
              assetToken.description ?? '',
              textStyle: theme.textTheme.ppMori400White14,
              onTapUrl: (url) async {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
                return true;
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        if (widget.exhibition != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: exhibitionInfo(
                context,
                widget.exhibition!,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: artworkDetailsMetadataSection(
              context,
              assetToken,
              artistName,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: artworkDetailsRightSection(
              context,
              assetToken,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 100),
            child: SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _tokenPreview(BuildContext context, AssetToken assetToken) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ColoredBox(
      color: AppColor.auGreyBackground,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: tokenGalleryThumbnailWidget(
              context,
              CompactedAssetToken.fromAssetToken(assetToken),
              screenWidth.toInt(),
            ),
          ),
          const Divider(
            color: AppColor.primaryBlack,
            height: 1,
          ),
          if (assetToken.canInteract)
            Container(
              padding: const EdgeInsets.all(16),
              child: _interactButton(context),
            ),
        ],
      ),
    );
  }

  Widget _interactButton(BuildContext context) {
    final castingDevice = BluetoothDeviceManager().castingBluetoothDevice;
    return PrimaryButton(
      onTap: () {
        injector<NavigationService>().navigateTo(
          AppRouter.keyboardControlPage,
          arguments: KeyboardControlPagePayload(
            '',
            '',
            [if (castingDevice != null) castingDevice],
          ),
        );
      },
      color: AppColor.white,
      text: 'interact'.tr(),
    );
  }
}
