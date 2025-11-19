//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/release_note.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/release_note_content.dart';
import 'package:flutter/material.dart';

class ReleaseNoteDetailPage extends StatefulWidget {
  const ReleaseNoteDetailPage({required this.releaseNote, super.key});

  final ReleaseNote releaseNote;

  @override
  State<ReleaseNoteDetailPage> createState() => _ReleaseNoteDetailPageState();
}

class _ReleaseNoteDetailPageState extends State<ReleaseNoteDetailPage> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: widget.releaseNote.date,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ReleaseNoteContent(releaseNote: widget.releaseNote),
    );
  }
}
