//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//
import 'package:autonomy_flutter/nft_collection/models/predefined_collection_model.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_screen.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/medium_category_ext.dart';
import 'package:autonomy_flutter/util/predefined_collection_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PredefinedCollectionIcon extends StatelessWidget {
  final PredefinedCollectionModel predefinedCollection;
  final PredefinedCollectionType type;

  const PredefinedCollectionIcon(
      {required this.predefinedCollection, required this.type, super.key});

  static const iconArtistHeight = 42.0;

  static double get height => iconArtistHeight;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case PredefinedCollectionType.medium:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColor.auGreyBackground,
          ),
          child: SvgPicture.asset(
            MediumCategoryExt.icon(predefinedCollection.id),
            width: 22,
            colorFilter:
                const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
          ),
        );
      case PredefinedCollectionType.artist:
        final compactedAssetTokens = predefinedCollection.compactedAssetToken;
        return SizedBox(
          width: 42,
          height: iconArtistHeight,
          child: tokenGalleryThumbnailWidget(context, compactedAssetTokens, 100,
              usingThumbnailID: false,
              galleryThumbnailPlaceholder: Container(
                width: 42,
                height: 42,
                color: AppColor.auLightGrey,
              )),
        );
    }
  }
}
