import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_exhibition_view.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AlumniExhibitionsPagePayload {
  final AlumniAccount alumni;

  AlumniExhibitionsPagePayload(this.alumni);
}

class AlumniExhibitionsPage extends StatefulWidget {
  final AlumniExhibitionsPagePayload payload;

  const AlumniExhibitionsPage({required this.payload, super.key});

  @override
  State<AlumniExhibitionsPage> createState() => _AlumniExhibitionsPageState();
}

class _AlumniExhibitionsPageState extends State<AlumniExhibitionsPage> {
  List<Exhibition>? _exhibitions;

  Future<List<Exhibition>> _fetchExhibitions() async {
    final alumni = widget.payload.alumni;
    final response = await injector<FeralFileService>().getAllExhibitions(
      relatedAlumniAccountIDs: alumni.allRelatedAccountIDs,
    );

    setState(() {
      _exhibitions = response;
    });
    return response;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_fetchExhibitions());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alumni = widget.payload.alumni;
    return Scaffold(
      appBar: getFFAppBar(context,
          onBack: () => Navigator.of(context).pop(),
          title: Column(
            children: [
              Text(
                alumni.displayAlias,
                style: theme.textTheme.ppMori400White14,
              ),
              const SizedBox(height: 4),
              Text('exhibitions'.tr(), style: theme.textTheme.ppMori700White14),
            ],
          )),
      backgroundColor: AppColor.primaryBlack,
      body: _buildBody(context),
    );
  }

  Widget _loadingView(BuildContext context) => const Center(
        child: LoadingWidget(),
      );

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
        child: Text('no_exhibition_found'.tr(),
            style: theme.textTheme.ppMori400White14));
  }

  Widget _buildBody(BuildContext context) {
    final exhibitions = _exhibitions;
    if (exhibitions == null) {
      return _loadingView(context);
    }
    if (exhibitions.isEmpty) {
      return _emptyView(context);
    }
    return ListExhibitionView(
      exhibitions: exhibitions,
      padding: const EdgeInsets.only(bottom: 48, top: 32),
    );
  }
}
