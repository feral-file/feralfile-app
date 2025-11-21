//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/release_note.dart';
import 'package:autonomy_flutter/view/release_note_content.dart';
import 'package:flutter/material.dart';

class ReleaseNoteBottomSheet extends StatelessWidget {
  const ReleaseNoteBottomSheet({
    required this.releaseNote,
    super.key,
  });

  final ReleaseNote releaseNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ReleaseNoteContent(releaseNote: releaseNote),
    );
  }
}
