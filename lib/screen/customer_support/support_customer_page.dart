//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/nft_rendering/feralfile_webview.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/au_buttons.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/badge_view.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/tappable_forward_row.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SupportCustomerPage extends StatefulWidget {
  const SupportCustomerPage({super.key});

  @override
  State<SupportCustomerPage> createState() => _SupportCustomerPageState();
}

class _SupportCustomerPageState extends State<SupportCustomerPage>
    with RouteAware, WidgetsBindingObserver {
  bool _isDocsVisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(injector<CustomerSupportService>().getChatThreads());
    // Trigger fade in animation after a frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isDocsVisible = true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    unawaited(injector<CustomerSupportService>().getChatThreads());
    super.didPopNext();
  }

  @override
  void dispose() {
    super.dispose();
    routeObserver.unsubscribe(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'how_can_we_help'.tr(),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            addTitleSpace(),
            Padding(
              padding: ResponsiveLayout.pageHorizontalEdgeInsets,
              child: _reportItemsWidget(),
            ),
            const SizedBox(height: 30),
            addOnlyDivider(),
            _resourcesWidget(),
            Expanded(child: _docsWebviewWidget(context))
          ],
        ),
      ),
    );
  }

  Widget _reportItemsWidget() => Column(
        children: [
          ...ReportIssueType.getSuggestList.map(
            (item) => Column(
              children: [
                AuSecondaryButton(
                  text: ReportIssueType.toTitle(item),
                  onPressed: () async {
                    await Navigator.of(context).pushNamed(
                      AppRouter.supportThreadPage,
                      arguments: NewIssuePayload(reportIssueType: item),
                    );
                  },
                  backgroundColor: Colors.white,
                  borderColor: AppColor.primaryBlack,
                  textColor: AppColor.primaryBlack,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      );

  Widget _resourcesWidget() {
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<int>?>(
      valueListenable: injector<CustomerSupportService>().numberOfIssuesInfo,
      builder: (
        BuildContext context,
        List<int>? numberOfIssuesInfo,
        Widget? child,
      ) {
        if (numberOfIssuesInfo == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (numberOfIssuesInfo[0] == 0) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TappableForwardRow(
              leftWidget: Row(
                children: [
                  Text(
                    'support_history'.tr(),
                    style: theme.textTheme.ppMori400Black14,
                  ),
                  if (numberOfIssuesInfo[1] > 0) ...[
                    const SizedBox(
                      width: 7,
                    ),
                    redDotIcon(),
                  ],
                ],
              ),
              rightWidget: numberOfIssuesInfo[1] > 0
                  ? BadgeView(number: numberOfIssuesInfo[1])
                  : null,
              onTap: () async {
                await Navigator.of(context)
                    .pushNamed(AppRouter.supportListPage);
              },
              padding: ResponsiveLayout.tappableForwardRowEdgeInsets,
            ),
            addOnlyDivider(),
          ],
        );
      },
    );
  }

  Widget _docsWebviewWidget(BuildContext context) {
    final url = injector<RemoteConfigService>().getConfig<String>(
        ConfigGroup.documentation,
        ConfigKey.docsUrl,
        'https://docs.feralfile.com/ff1?from=app');
    final uri = Uri.parse(url);
    return FeralFileWebview(
      uri: uri,
    );
  }
}
