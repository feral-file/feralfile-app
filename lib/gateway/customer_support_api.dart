//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/customer_support.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'customer_support_api.g.dart';

@RestApi(baseUrl: '')
abstract class CustomerSupportApi {
  factory CustomerSupportApi(Dio dio, {String baseUrl}) = _CustomerSupportApi;

  static const String issuesPath = '/v1/issues/';

  static const String apiKeyHeader = 'x-api-key';
  static const String deviceIdHeader = 'x-device-id';

  @GET(issuesPath)
  Future<List<Issue>> getIssues({
    @Header('Authorization') required String token,
  });

  @GET(issuesPath)
  Future<List<Issue>> getAnonymousIssues({
    @Header(apiKeyHeader) required String apiKey,
    @Header(deviceIdHeader) required String deviceId,
  });

  @GET('/v1/issues/{issueID}')
  Future<IssueDetails> getDetails(
    @Path('issueID') String issueID, {
    @Query('reverse') bool reverse = true,
  });

  @POST(issuesPath)
  Future<PostedMessageResponse> createIssue(
    @Body() Map<String, Object> body, {
    @Header('Authorization') required String token,
  });

  @POST(issuesPath)
  Future<PostedMessageResponse> createAnonymousIssue(
    @Body() Map<String, Object> body, {
    @Header(apiKeyHeader) required String apiKey,
    @Header(deviceIdHeader) required String deviceId,
  });

  @POST('/v1/issues/{issueID}')
  Future<PostedMessageResponse> commentIssue(
    @Path('issueID') String issueID,
    @Body() Map<String, Object> body,
  );

  @PATCH('/v1/issues/{issueID}/reopen')
  Future<void> reOpenIssue(
    @Path('issueID') String issueID,
  );

  @POST('/v1/issues/{issueID}/rate/{rating}')
  Future<void> rateIssue(
    @Path('issueID') String issueID,
    @Path('rating') int rating,
  );
}
