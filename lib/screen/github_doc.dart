//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/dio_interceptors.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/util/locale_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';

class GithubDocPage extends StatefulWidget {
  final GithubDocPayload payload;

  const GithubDocPage({required this.payload, super.key});

  @override
  State<GithubDocPage> createState() => _GithubDocPageState();

  static const String ffDocsAppsPrefix =
      '/bitmark-inc/feral-file-docs/main/app';
  static const String ffDocsAgreementsPrefix =
      '/bitmark-inc/feral-file-docs/main/agreements';
}

class _GithubDocPageState extends State<GithubDocPage> {
  final _navigationService = injector<NavigationService>();

  final dio = DioManager().base(BaseOptions(
    baseUrl: 'https://raw.githubusercontent.com',
    connectTimeout: const Duration(seconds: 5),
  ));

  static const List<String> _supportedLanguages = ['en_US'];

  @override
  void initState() {
    super.initState();
    dio.interceptors.add(LoggingInterceptor());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getBackAppBar(
          context,
          title: widget.payload.title,
          onBack: () => Navigator.of(context).pop(),
        ),
        body: Container(
          margin: ResponsiveLayout.pageEdgeInsets,
          child: FutureBuilder<Response<String>>(
            builder: (context, snapshot) => CustomScrollView(
              slivers: [_contentView(context, snapshot)],
            ),
            // ignore: discarded_futures
            future: dio.get<String>(_githubPath()),
          ),
        ),
      );

  Widget _contentView(
      BuildContext context, AsyncSnapshot<Response<String>> snapshot) {
    final theme = Theme.of(context);

    if (snapshot.hasData && snapshot.data?.statusCode == 200) {
      return SliverToBoxAdapter(
          child: Markdown(
              key: const Key('githubMarkdown'),
              data: snapshot.data!.data!,
              softLineBreak: true,
              shrinkWrap: true,
              selectable: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 50),
              styleSheet: markDownLightStyle(context),
              onTapLink: (text, href, title) async {
                if (href == null) {
                  return;
                }
                if (href.isAutonomyDocumentLink) {
                  await _navigationService.openAutonomyDocument(href, title);
                } else {
                  await launchUrlString(href);
                }
              }));
    } else if (snapshot.hasError ||
        (snapshot.data != null && snapshot.data?.statusCode != 200)) {
      return SliverFillRemaining(
          child: Center(
              child: Text(
        'error_loading_content'.tr(),
        style: theme.textTheme.headlineMedium,
      )));
    } else {
      return const SliverFillRemaining(
          child: Center(child: CupertinoActivityIndicator()));
    }
  }

  String _githubPath() {
    final prefix = widget.payload.prefix;
    final document = widget.payload.document;
    final language = widget.payload.fileNameAsLanguage
        ? '/${_getLanguage()}$markdownExt'
        : '';

    final String link = prefix + document + language;
    return link.endsWith(markdownExt) ? link : '$link$markdownExt';
  }

  String _getLanguage() {
    final language = EasyLocalization.of(context)?.locale.localeCode ?? '';
    return _supportedLanguages.contains(language)
        ? language
        : _supportedLanguages.first;
  }
}

class GithubDocPayload {
  final String title;
  final String prefix;
  final String document;

  /// If true, full url would be `https://raw.githubusercontent.com/{prefix}/{document}/en_US.md`
  /// If false, full url would be `https://raw.githubusercontent.com/{prefix}/{document}.md`
  final bool fileNameAsLanguage;

  GithubDocPayload({
    required this.title,
    required this.prefix,
    required this.document,
    this.fileNameAsLanguage = false,
  });
}
