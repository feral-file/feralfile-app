import 'package:autonomy_flutter/common/database.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database_manager.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc.dart';
export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc_event.dart';
export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_grid_widget.dart';

class NftCollection {
  static Logger logger = Logger('nft_collection');
  static Logger apiLog = Logger('nft_collection_api_log');
  static late NftTokensServiceImpl tokenService;
  static late NftCollectionPrefs prefs;
  static late IndexerDatabaseAbstract database;

  static Future<void> initNftCollection({
    required String indexerUrl,
    String databaseFileName = 'nft_collection_v2.db',
    Logger? logger,
    Logger? apiLogger,
    Dio? dio,
  }) async {
    if (logger != null) {
      NftCollection.logger = logger;
    }

    final store = ObjectBox.store;
    database = IndexerDataBaseObjectBox(store);
    prefs = NftCollectionPrefs(await SharedPreferences.getInstance());

    tokenService = NftTokensServiceImpl(indexerUrl, database, prefs, dio);
  }
}
