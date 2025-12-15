//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

class SystemException implements Exception {
  final String reason;

  SystemException(this.reason);
}

class AbortedException implements Exception {}

class LinkingFailedException implements Exception {}

class FailedFetchBackupVersion implements Exception {}
