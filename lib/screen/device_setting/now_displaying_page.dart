import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/ff_artwork_thumbnail_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';

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
      final nowDisplayingItem = object.currentItem;
      final dP1Manifest = nowDisplayingItem.dp1Manifest;
      final assetToken = nowDisplayingItem.assetToken;

      final identitiesList = <String>[];

      if (dP1Manifest != null) {
        // TODO: add dP1Manifest identities
      }

      if (assetToken != null) {
        final provenanceIdentities = assetToken.provenance
            .map((e) => e.toAddress)
            .nonNulls
            .toSet()
            .toList();

        final artistIdentities =
            assetToken.getArtists.map((e) => e.name).toList();
        identitiesList.addAll(provenanceIdentities);
        identitiesList.addAll(artistIdentities);
      }

      context.read<IdentityBloc>().add(GetIdentityEvent(identitiesList));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MainAppBar(
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
          style: AppTypography.body(context).white,
        );
      case ConnectionLost:
        final device = (nowDisplayingStatus! as ConnectionLost).device;
        return Text(
          '${device.name} connection lost',
          style: AppTypography.body(context).white,
        );
      default:
        return Text('Unknown state', style: AppTypography.body(context).white);
    }
  }

  Widget _tokenNowDisplaying(
    BuildContext context,
    NowDisplayingSuccess nowDisplayingStatus,
  ) {
    Theme.of(context);
    return BlocConsumer<ArtworkDetailBloc, ArtworkDetailState>(
      listener: (context, state) {
        final provenanceIdentities = state.assetToken?.provenance
                .map((e) => e.toAddress)
                .nonNulls
                .toSet()
                .toList() ??
            [];
        final artistIdentities =
            state.assetToken?.getArtists.map((e) => e.name).toList() ?? [];
        final identitiesList = <String>[];
        identitiesList.addAll(provenanceIdentities);
        identitiesList.addAll(artistIdentities);
        context.read<IdentityBloc>().add(GetIdentityEvent(identitiesList));
      },
      builder: (context, state) {
        final object = nowDisplayingStatus.object as DP1NowDisplayingObject;
        final nowDisplayingItem = object.currentItem;

        return DP1NowDisplaying(
          nowDisplayingItem: nowDisplayingItem,
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
            onSubTitleTap: null,
          ),
        ),
      ],
    ),
  );
}

class DP1NowDisplaying extends StatefulWidget {
  const DP1NowDisplaying({
    required this.nowDisplayingItem,
    super.key,
  });

  @override
  State<DP1NowDisplaying> createState() => _DP1NowDisplayingState();

  final DP1NowDisplayingItem nowDisplayingItem;
}

class _DP1NowDisplayingState extends State<DP1NowDisplaying> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetToken = widget.nowDisplayingItem.assetToken;
    final identityState = context.watch<IdentityBloc>().state;
    final artistName = assetToken?.getArtists.firstOrNull?.name
        .toIdentityOrMask(identityState.identityMap);
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 30,
          ),
        ),
        SliverToBoxAdapter(
          child: _tokenPreview(context, widget.nowDisplayingItem),
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
                assetToken.displayDescription,
                textStyle: AppTypography.body(context).white,
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

  Widget _tokenPreview(
      BuildContext context, DP1NowDisplayingItem nowDisplayingItem) {
    final thumbnail = nowDisplayingItem.thumbnail;
    final screenWidth = MediaQuery.of(context).size.width;
    return ColoredBox(
      color: AppColor.auGreyBackground,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: (thumbnail != null)
                ? FFArtworkThumbnailView(
                    url: thumbnail.uri,
                  )
                : const GalleryNoThumbnailWidget(),
          ),
          const Divider(
            color: AppColor.primaryBlack,
            height: 1,
          ),
          if (nowDisplayingItem.canInteract)
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
