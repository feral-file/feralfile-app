//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/feralfile_docs_api.dart';
import 'package:autonomy_flutter/model/release_note.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/change_log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReleaseNotesPage extends StatefulWidget {
  const ReleaseNotesPage({super.key});

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  List<ReleaseNote> _releaseNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReleaseNotes();
  }

  Future<void> _loadReleaseNotes() async {
    try {
      final changeLogs = await injector<FeralFileDocsAPI>().getChangeLogs();
      setState(() {
        _releaseNotes = parseChangeLogs(changeLogs);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    UIHelper.currentDialogTitle = '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'release_notes'.tr(),
        onBack: () => Navigator.of(context).pop(),
      ),
      backgroundColor: theme.colorScheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _releaseNotes.length,
              itemBuilder: (context, index) {
                final releaseNote = _releaseNotes[index];
                return _ReleaseNoteItem(
                  releaseNote: releaseNote,
                  onTap: () {
                    injector<NavigationService>().navigateTo(
                      AppRouter.releaseNoteDetailPage,
                      arguments: releaseNote,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ReleaseNoteItem extends StatelessWidget {
  const _ReleaseNoteItem({
    required this.releaseNote,
    required this.onTap,
  });

  final ReleaseNote releaseNote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColor.auLightGrey,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    releaseNote.date,
                    style: theme.textTheme.ppMori400Black12,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    releaseNote.title,
                    style: theme.textTheme.ppMori400Black14,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SvgPicture.asset(
              'assets/images/iconForward.svg',
              width: 9,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppColor.auGrey,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
