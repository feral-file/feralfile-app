import 'package:autonomy_flutter/common/database.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database_manager.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc.dart';
export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc_event.dart';
export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_grid_widget.dart';

class NftCollection {
  static Logger logger = log;
  static Logger apiLog = log;
  static late NftTokensServiceImpl tokenService;
  static late NftCollectionPrefs prefs;
  static late IndexerDatabaseAbstract database;

  static Future<void> initNftCollection({
    required String indexerUrl,
    Logger? logger,
    Logger? apiLogger,
  }) async {
    if (logger != null) {
      NftCollection.logger = logger;
      NftCollection.apiLog = logger;
    }

    final store = ObjectBox.store;
    database = IndexerDataBaseObjectBox(store);
    prefs = NftCollectionPrefs(await SharedPreferences.getInstance());
    tokenService = NftTokensServiceImpl(indexerUrl, database, prefs);
  }
}
