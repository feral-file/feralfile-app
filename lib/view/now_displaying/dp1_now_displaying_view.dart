import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/now_displaying/base_now_displaying_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DP1NowDisplayingView extends StatelessWidget {
  DP1NowDisplayingView(this.object, {super.key}) {
    _identityBloc.add(GetIdentityEvent([object.assetToken.artistName ?? '']));
  }

  final DP1NowDisplayingObject object;

  IdentityBloc get _identityBloc => injector<IdentityBloc>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetToken = object.assetToken;
    return BlocBuilder<IdentityBloc, IdentityState>(
      bloc: _identityBloc,
      builder: (context, state) {
        final artistTitle =
            assetToken.artistName?.toIdentityOrMask(state.identityMap) ??
                assetToken.artistName;
        return NowDisplayingView(
          device: object.connectedDevice,
          thumbnailBuilder: (context) {
            return AspectRatio(
              aspectRatio: 1,
              child: tokenGalleryThumbnailWidget(
                context,
                CompactedAssetToken.fromAssetToken(assetToken),
                65,
                useHero: false,
              ),
            );
          },
          titleBuilder: (context) {
            final title = assetToken.title ?? '';
            return Text(
              title,
              style: theme.textTheme.ppMori400Black14,
              overflow: TextOverflow.ellipsis,
            );
          },
          artistBuilder: (context) {
            final title = artistTitle ?? '';
            return Text(
              title,
              style: theme.textTheme.ppMori400Black14,
              overflow: TextOverflow.ellipsis,
            );
          },
          customAction: [
            ValueListenableBuilder(
              valueListenable: CustomRouteObserver.currentRoute,
              builder: (context, route, child) {
                if (route?.isRecordScreenShowing ?? false) {
                  return const SizedBox.shrink();
                }
                return child!;
              },
              child: GestureDetector(
                child: Container(
                  height: 22,
                  width: 22,
                  decoration: BoxDecoration(
                    color: AppColor.feralFileLightBlue,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                onTap: () {
                  injector<NavigationService>().popToRouteOrPush(
                    AppRouter.voiceCommandPage,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
