// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //

// import 'package:dio/dio.dart';
// import 'package:autonomy_flutter/nft_collection/models/tzkt_operation.dart';
// import 'package:retrofit/retrofit.dart';

// part 'tzkt_api.g.dart';

// @RestApi(baseUrl: 'https://api.tzkt.io')
// abstract class TZKTApi {
//   factory TZKTApi(Dio dio, {String baseUrl}) = _TZKTApi;

//   @GET('/v1/tokens/transfers')
//   Future<List<TZKTTokenTransfer>> getTokenTransfer({
//     @Query('anyof.from.to') String? anyOf,
//     @Query('to') String? to,
//     @Query('sort.desc') String sort = 'id',
//     @Query('limit') int? limit,
//     @Query('lastId') int? lastId,
//     @Query('timestamp.gt') String? lastTime,
//   });
// }
