//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/gateway/feralfile_api.dart';
import 'package:autonomy_flutter/model/ff_account.dart';

enum ArtworkModel {
  multi,
  single,
  multiUnique,
  ;

  String get value {
    switch (this) {
      case ArtworkModel.multi:
        return 'multi';
      case ArtworkModel.single:
        return 'single';
      case ArtworkModel.multiUnique:
        return 'multi_unique';
    }
  }

  String get title {
    switch (this) {
      case ArtworkModel.multiUnique:
        return 'series';
      case ArtworkModel.single:
        return 'single';
      case ArtworkModel.multi:
        return 'edition';
    }
  }

  String get pluralTitle {
    switch (this) {
      case ArtworkModel.multiUnique:
        return 'series';
      case ArtworkModel.single:
        return 'singles';
      case ArtworkModel.multi:
        return 'editions';
    }
  }

  static ArtworkModel? fromString(String value) {
    switch (value) {
      case 'multi':
        return ArtworkModel.multi;
      case 'single':
        return ArtworkModel.single;
      case 'multi_unique':
        return ArtworkModel.multiUnique;
      default:
        return null;
    }
  }
}

enum ExtendedArtworkModel {
  interactiveInstruction,
  ;

  String get title {
    switch (this) {
      case ExtendedArtworkModel.interactiveInstruction:
        return 'interactive instruction';
    }
  }

  String get pluralTitle {
    switch (this) {
      case ExtendedArtworkModel.interactiveInstruction:
        return 'interactive instructions';
    }
  }

  static ExtendedArtworkModel? fromTitle(String title) {
    switch (title) {
      case 'interactive instruction':
        return ExtendedArtworkModel.interactiveInstruction;
      default:
        return null;
    }
  }
}

enum GenerativeMediumTypes {
  software,
  model,
  ;

  String get value {
    switch (this) {
      case GenerativeMediumTypes.software:
        return 'software';
      case GenerativeMediumTypes.model:
        return '3d';
    }
  }
}

abstract class FeralFileService {
  Future<FeralFileResaleInfo> getResaleInfo(String exhibitionID);
}

class FeralFileServiceImpl extends FeralFileService {
  FeralFileServiceImpl(
    this._feralFileApi,
  );
  final FeralFileApi _feralFileApi;
  @override
  Future<FeralFileResaleInfo> getResaleInfo(String exhibitionID) async {
    final resaleInfo = await _feralFileApi.getResaleInfo(exhibitionID);
    return resaleInfo.result;
  }
}
