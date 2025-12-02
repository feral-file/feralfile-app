//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/announcement/announcement.dart';
import 'package:autonomy_flutter/model/announcement/announcement_request.dart';
import 'package:autonomy_flutter/model/jwt.dart';
import 'package:autonomy_flutter/model/ok_response.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'iap_api.g.dart';

@RestApi(baseUrl: '')
abstract class IAPApi {
  factory IAPApi(Dio dio, {String baseUrl}) = _IAPApi;

  @DELETE('/apis/v1/premium/profile-data')
  Future deleteAllProfiles(
    @Header('requester') String requester,
  );

  @DELETE('/apis/v1/me')
  Future deleteUserData();

  @POST('/apis/v1/me/identity-hash')
  Future<OnesignalIdentityHash> generateIdentityHash(
    @Body() Map<String, String> body,
  );

  @GET('/apis/v2/notifications')
  Future<List<Announcement>> getAnnouncements(@Body() AnnouncementRequest body);

  @POST('/apis/v2/gift-code/{id}/redeem')
  Future<OkResponse> redeemGiftCode(
    @Path('id') String id,
  );

  @PATCH('/apis/metric-devices/{id}')
  Future<void> updateMetrics(
    @Path('id') String deviceId,
  );

  @POST('/apis/metrics')
  Future<void> sendEvent(
    @Body() Map<String, dynamic> metrics,
    @Header('x-device-id') String deviceId,
  );

  @DELETE('/apis/metric-devices/{id}')
  Future<void> deleteMetrics(
    @Path('id') String deviceId,
  );

  @PATCH('/apis/v2/addresses/referral')
  Future<void> registerReferralCode(@Body() Map<String, dynamic> body);

  @GET('/apis/memberships/subscriptions/portal')
  Future<dynamic> portalUrl();

  @GET('/apis/memberships/subscriptions/active')
  Future<dynamic> getCustomActiveSubscription();

  @PATCH('/apis/users/devices/artwork-configurations')
  Future<dynamic> updateArtworkConfigurations(
      @Body() Map<String, dynamic> body);
}
