// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //

// import 'package:autonomy_flutter/model/explore_statistics_data.dart';
// import 'package:autonomy_flutter/model/ff_account.dart';
// import 'package:autonomy_flutter/model/ff_list_response.dart';
// import 'package:dio/dio.dart';
// import 'package:retrofit/retrofit.dart';

// part 'feralfile_api.g.dart';

// @RestApi(baseUrl: '')
// abstract class FeralFileApi {
//   factory FeralFileApi(Dio dio, {String baseUrl}) = _FeralFileApi;

//   @GET('/api/exhibitions/{exhibitionID}/revenue-setting/resale')
//   Future<ResaleResponse> getResaleInfo(
//       @Path('exhibitionID') String exhibitionID);
// }

// class FeralFileResponse<T> {
//   T result;

//   FeralFileResponse({required this.result});

//   factory FeralFileResponse.fromJson(Map<String, dynamic> json,
//           {T Function(Map<String, dynamic>)? fromJson}) =>
//       FeralFileResponse(
//         result: fromJson != null
//             ? fromJson(json['result'] as Map<String, dynamic>)
//             : json['result'] as T,
//       );

//   Map<String, dynamic> toJson() => {
//         'result': result,
//       };
// }
