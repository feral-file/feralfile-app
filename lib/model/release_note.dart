//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

class ReleaseNote {
  const ReleaseNote({
    required this.date,
    required this.title,
    required this.content,
  });

  final String date;
  final String title;
  final String content;
}

