//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/au_buttons.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';

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
          ],
        ),
      ),
    );
  }

  Widget _reportItemsWidget() => Column(
        children: [
          AuSecondaryButton(
            text: 'Contact Feral File',
            onPressed: () =>
                injector<NavigationService>().showCustomerSupport(),
            backgroundColor: Colors.white,
            borderColor: AppColor.primaryBlack,
            textColor: AppColor.primaryBlack,
          ),
        ],
      );
}
