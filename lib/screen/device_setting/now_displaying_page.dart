import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
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
      if (assetToken == null) {
        return;
      }
      final identitiesList = assetToken.provenance.map((e) => e.owner).toList();
      if (assetToken.artistName != null && assetToken.artistName!.length > 20) {
        identitiesList.add(assetToken.artistName!);
      }

      identitiesList.add(assetToken.owner);
      context.read<IdentityBloc>().add(GetIdentityEvent(identitiesList));
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        centeredTitle: 'now_displaying'.tr(),
        backgroundColor: PrimitivesTokens.colorsBlack,
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => injector<NavigationService>().showDeviceSettings(),
            constraints: const BoxConstraints(
              maxWidth: 44,
              maxHeight: 44,
              minWidth: 44,
              minHeight: 44,
            ),
            icon: SvgPicture.asset(
              'assets/images/more_circle.svg',
              width: 22,
              height: 22,
            ),
          ),
        ],
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
          return _tokenNowDisplaying(
              context, nowDisplayingStatus! as NowDisplayingSuccess);
        }
        return const SizedBox();
      case DeviceDisconnected:
        final device = (nowDisplayingStatus! as DeviceDisconnected).device;
        return Text(
          '${device.name} disconnected',
          style: theme.textTheme.ppMori400White14,
        );
      case ConnectionLost:
        final device = (nowDisplayingStatus! as ConnectionLost).device;
        return Text(
          '${device.name} connection lost',
          style: theme.textTheme.ppMori400White14,
        );
      default:
        return Text('Unknown state', style: theme.textTheme.ppMori400White14);
    }
  }

  Widget _tokenNowDisplaying(
    BuildContext context,
    NowDisplayingSuccess nowDisplayingStatus,
  ) {
    Theme.of(context);
    return BlocConsumer<ArtworkDetailBloc, ArtworkDetailState>(
      listener: (context, state) {
        final identitiesList =
            state.assetToken?.provenance.map((e) => e.owner).toList() ?? [];
        if (state.assetToken?.artistName != null &&
            state.assetToken!.artistName!.length > 20) {
          identitiesList.add(state.assetToken!.artistName!);
        }

        identitiesList.add(state.assetToken?.owner ?? '');
        context.read<IdentityBloc>().add(GetIdentityEvent(identitiesList));
      },
      builder: (context, state) {
        final object = nowDisplayingStatus.object as DP1NowDisplayingObject;
        final dp1Item = object.playlistItem;
        final assetToken = object.assetToken;

        return DP1NowDisplaying(
          dp1Item: dp1Item,
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

class DP1NowDisplaying extends StatefulWidget {
  const DP1NowDisplaying({
    required this.dp1Item,
    this.assetToken,
    super.key,
  });

  @override
  State<DP1NowDisplaying> createState() => _DP1NowDisplayingState();

  final DP1Item dp1Item;
  final AssetToken? assetToken;
}

class _DP1NowDisplayingState extends State<DP1NowDisplaying> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetToken = widget.assetToken;
    final identityState = context.watch<IdentityBloc>().state;
    final artistName =
        assetToken?.artistName?.toIdentityOrMask(identityState.identityMap);
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
        if (assetToken != null)
          SliverToBoxAdapter(
            child: infoHeader(context, assetToken, artistName),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        if (assetToken != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HtmlWidget(
                customStylesBuilder: auHtmlStyle,
                assetToken.description ?? '',
                textStyle: theme.textTheme.ppMori400White12,
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
        if (assetToken != null)
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
        if (assetToken != null)
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

  Widget _tokenPreview(BuildContext context, AssetToken? assetToken) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ColoredBox(
      color: AppColor.auGreyBackground,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: (assetToken != null)
                ? tokenGalleryThumbnailWidget(
                    context,
                    CompactedAssetToken.fromAssetToken(assetToken),
                    screenWidth.toInt(),
                  )
                : const GalleryNoThumbnailWidget(),
          ),
          const Divider(
            color: AppColor.primaryBlack,
            height: 1,
          ),
          if (assetToken != null && assetToken.canInteract)
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
