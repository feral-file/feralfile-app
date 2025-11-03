// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //
//
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
//
// // ignore: depend_on_referenced_packages
// import 'package:path/path.dart' as p;
//
// import 'nft_collection_bloc_event.dart';
//
// typedef OnTapCallBack = void Function(CompactedAssetToken);
//
// typedef LoadingIndicatorBuilder = Widget Function(BuildContext context);
//
// typedef EmptyGalleryViewBuilder = Widget Function(BuildContext context);
//
// typedef CustomGalleryViewBuilder = Widget Function(
//     BuildContext context, List<CompactedAssetToken> tokens);
//
// typedef ItemViewBuilder = Widget Function(
//     BuildContext context, CompactedAssetToken asset);
//
// class NftCollectionGrid extends StatelessWidget {
//   final NftLoadingState state;
//   final List<CompactedAssetToken> tokens;
//   final int? columnCount;
//   final double itemSpacing;
//   final LoadingIndicatorBuilder loadingIndicatorBuilder;
//   final EmptyGalleryViewBuilder? emptyGalleryViewBuilder;
//   final CustomGalleryViewBuilder? customGalleryViewBuilder;
//   final ItemViewBuilder itemViewBuilder;
//   final OnTapCallBack? onTap;
//
//   const NftCollectionGrid({
//     Key? key,
//     required this.state,
//     required this.tokens,
//     this.columnCount,
//     this.itemSpacing = 3.0,
//     this.loadingIndicatorBuilder = _buildLoadingIndicator,
//     this.emptyGalleryViewBuilder,
//     this.customGalleryViewBuilder,
//     this.itemViewBuilder = buildDefaultItemView,
//     this.onTap,
//   }) : super(key: key);
//
//   int _columnCount(BuildContext context) {
//     if (columnCount != null) {
//       return columnCount!;
//     } else {
//       final screenSize = MediaQuery.of(context).size;
//       if (screenSize.width > screenSize.height) {
//         return 5;
//       } else {
//         return 3;
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (tokens.isEmpty) {
//       if ([NftLoadingState.notRequested, NftLoadingState.loading]
//           .contains(state)) {
//         return loadingIndicatorBuilder(context);
//       } else {
//         if (emptyGalleryViewBuilder != null) {
//           return emptyGalleryViewBuilder!(context);
//         }
//       }
//     }
//     return customGalleryViewBuilder?.call(context, tokens) ??
//         GridView.builder(
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: _columnCount(context),
//             crossAxisSpacing: itemSpacing,
//             mainAxisSpacing: itemSpacing,
//           ),
//           itemBuilder: (context, index) {
//             final asset = tokens[index];
//             return GestureDetector(
//               onTap: () {
//                 onTap?.call(asset);
//               },
//               child: itemViewBuilder(context, asset),
//             );
//           },
//           itemCount: tokens.length,
//         );
//   }
// }
//
// Widget _buildLoadingIndicator(BuildContext context) {
//   return const Center(
//     child: SizedBox(
//       width: 27,
//       height: 27,
//       child: CircularProgressIndicator(
//         backgroundColor: Colors.black54,
//         color: Colors.black,
//         strokeWidth: 2,
//       ),
//     ),
//   );
// }
//
// Widget buildDefaultItemView(BuildContext context, CompactedAssetToken token) {
//   final ext = p.extension(token.thumbnailURL!);
//   const cachedImageSize = 1024;
//   const greyColor = Color.fromRGBO(227, 227, 227, 1);
//
//   return Hero(
//     tag: token.id,
//     child: ext == ".svg"
//         ? SvgPicture.network(token.galleryThumbnailURL!,
//             placeholderBuilder: (context) => Container(color: greyColor))
//         : Image.network(
//             token.galleryThumbnailURL!,
//             fit: BoxFit.cover,
//             cacheHeight: cachedImageSize,
//             cacheWidth: cachedImageSize,
//             loadingBuilder: (context, child, loadingProgress) {
//               if (loadingProgress == null) {
//                 return child;
//               }
//               return Container(color: greyColor);
//             },
//             errorBuilder: (context, error, stacktrace) => Container(
//                 color: greyColor,
//                 child: Center(
//                   child: SvgPicture.asset(
//                     'assets/images/image_error.svg',
//                     width: 75,
//                     height: 75,
//                   ),
//                 )),
//           ),
//   );
// }
