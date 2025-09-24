// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //
// import 'package:autonomy_flutter/nft_collection/models/predefined_collection_model.dart';
// import 'package:autonomy_flutter/screen/app_router.dart';
// import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_screen.dart';
// import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
// import 'package:autonomy_flutter/util/string_ext.dart';
// import 'package:autonomy_flutter/view/predefined_collection/predefined_collection_icon.dart';
// import 'package:flutter/material.dart';
//
// class PredefinedCollectionItem extends StatelessWidget {
//   final PredefinedCollectionModel predefinedCollection;
//   final PredefinedCollectionType type;
//   final String searchStr;
//
//   const PredefinedCollectionItem(
//       {required this.predefinedCollection,
//       required this.type,
//       required this.searchStr,
//       super.key});
//
//   static const verticalPadding = 15.0;
//
//   static double get height =>
//       verticalPadding * 2 + PredefinedCollectionIcon.height;
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     var title = predefinedCollection.name ?? predefinedCollection.id;
//     if (predefinedCollection.name == predefinedCollection.id) {
//       title = title.maskOnly(5);
//     }
//     final titleStyle = theme.textTheme.ppMori400White14;
//     return GestureDetector(
//       onTap: () async {
//         await Navigator.pushNamed(
//           context,
//           AppRouter.predefinedCollectionPage,
//           arguments: PredefinedCollectionScreenPayload(
//             type: type,
//             predefinedCollection: predefinedCollection,
//             filterStr: searchStr,
//           ),
//         );
//       },
//       child: Container(
//         color: Colors.transparent,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: verticalPadding),
//           child: Row(
//             children: [
//               PredefinedCollectionIcon(
//                 predefinedCollection: predefinedCollection,
//                 type: type,
//               ),
//               const SizedBox(width: 33),
//               Expanded(
//                 child: Text(
//                   title,
//                   style: titleStyle,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               Text('${predefinedCollection.total}',
//                   style: theme.textTheme.ppMori400Grey14),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
