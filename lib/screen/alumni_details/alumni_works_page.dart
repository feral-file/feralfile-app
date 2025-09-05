import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/feralfile_home/artwork_view.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AlumniWorksPagePayload {
  final AlumniAccount alumni;

  AlumniWorksPagePayload(this.alumni);
}

class AlumniWorksPage extends StatefulWidget {
  final AlumniWorksPagePayload payload;

  const AlumniWorksPage({required this.payload, super.key});

  @override
  State<AlumniWorksPage> createState() => _AlumniWorksPageState();
}

class _AlumniWorksPageState extends State<AlumniWorksPage> {
  List<FFSeries>? _seriesList;
  List<UserCollection>? _userCollections;

  Future<List<FFSeries>> _fetchSeriesList() async {
    final alumni = widget.payload.alumni;
    final response = await injector<FeralFileService>().exploreArtworks(
      artistIds: alumni.allRelatedAccountIDs,
    );

    final indexerCollections = await injector<NftIndexerService>()
        .getCollectionsByAddresses(alumni.allRelatedAddresses);

    setState(() {
      _seriesList = response.result;
      _userCollections = indexerCollections;
    });
    return response.result;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_fetchSeriesList());
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
              Text('_artworks'.tr(), style: theme.textTheme.ppMori700White14),
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
      child: Text(
        'no_artwork_found'.tr(),
        style: theme.textTheme.ppMori400White14,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final seriesList = _seriesList;
    if (seriesList == null) {
      return _loadingView(context);
    }
    if (seriesList.isEmpty) {
      return _emptyView(context);
    }
    return SeriesView(
      series: seriesList,
      userCollections: _userCollections ?? [],
      padding: const EdgeInsets.only(bottom: 48),
      artist: widget.payload.alumni,
    );
  }
}
