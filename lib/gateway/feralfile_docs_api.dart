//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'feralfile_docs_api.g.dart';

@RestApi(baseUrl: '')
abstract class FeralFileDocsAPI {
  factory FeralFileDocsAPI(Dio dio, {String baseUrl}) = _FeralFileDocsAPI;

  @GET('/changelog.md')
  Future<String> getChangeLog();
}
