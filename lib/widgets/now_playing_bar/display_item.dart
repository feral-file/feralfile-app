import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/DisplayItem.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/text_style_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DisplayItem extends StatelessWidget {
  const DisplayItem({
    required this.dp1Item,
    this.assetToken,
    this.deviceName,
    this.isPlaying = true,
    this.isInExpandedView = false,
    this.onTap,
    super.key,
  });

  final DP1Item dp1Item;
  final AssetToken? assetToken;
  final String? deviceName;
  final bool isPlaying;
  final bool isInExpandedView;
  final VoidCallback? onTap;
  IdentityBloc get _identityBloc => injector<IdentityBloc>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        width: double.infinity,
        child: Opacity(
          opacity: isPlaying ? 1 : 0.5,
          child: Row(
            crossAxisAlignment: isInExpandedView
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: DisplayItemTokens.thumbWidth,
                height: DisplayItemTokens.thumbHeight.toDouble(),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: DisplayItemTokens.thumbImageWidth,
                        height: DisplayItemTokens.thumbImageHeight.toDouble(),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        child: _thumbnail(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: DisplayItemTokens.gap.toDouble()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (deviceName != null)
                      Text(
                        deviceName!.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize:
                              DisplayItemTokens.textDeviceFontSize.toDouble(),
                          fontWeight: FontWeightUtil.fromString(
                            DisplayItemTokens.textDeviceFontWeight,
                          ),
                          height: DisplayItemTokens.textDeviceLineHeight /
                              DisplayItemTokens.textDeviceFontSize,
                          color: DisplayItemTokens.textColor,
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlocBuilder<IdentityBloc, IdentityState>(
                          bloc: _identityBloc,
                          builder: (context, state) {
                            final artistTitle = assetToken?.artistName
                                    ?.toIdentityOrMask(state.identityMap) ??
                                assetToken?.artistName;
                            return Text(
                              artistTitle ?? 'Unknown Artist',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.small,
                            );
                          },
                        ),
                        Transform.translate(
                          offset: Offset(
                            0,
                            DisplayItemTokens.textArtworkGap.toDouble(),
                          ),
                          child: Text(
                            dp1Item.title ??
                                assetToken?.displayTitle ??
                                'Unknown Title',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: isInExpandedView
                                ? Theme.of(context).textTheme.small.copyWith(
                                      fontWeight: FontWeightUtil.fromString(
                                        PrimitivesTokens.fontWeightsBold,
                                      ),
                                      fontStyle: FontStyle.italic,
                                    )
                                : Theme.of(context).textTheme.small,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context) {
    final assetToken = this.assetToken;
    if (assetToken == null) {
      return const GalleryNoThumbnailWidget();
    }
    return tokenGalleryThumbnailWidget(
      context,
      CompactedAssetToken.fromAssetToken(assetToken),
      DisplayItemTokens.thumbImageWidth.toInt(),
      ratio: DisplayItemTokens.thumbImageWidth /
          DisplayItemTokens.thumbImageHeight,
    );
  }
}
