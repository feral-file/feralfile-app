import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:autonomy_flutter/nft_collection/database/nft_collection_database.dart';
import 'package:autonomy_flutter/nft_collection/services/address_service.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc.dart';
export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc_event.dart';
export 'package:autonomy_flutter/nft_collection/widgets/nft_collection_grid_widget.dart';

class NftCollection {
  static Logger logger = Logger('nft_collection');
  static Logger apiLog = Logger('nft_collection_api_log');
  static late TokensServiceImpl tokenService;
  static late NftCollectionPrefs prefs;
  static late NftCollectionDatabase database;
  static late AddressService addressService;

  static Future<void> initNftCollection({
    String databaseFileName = 'nft_collection_v2.db',
    Logger? logger,
    Logger? apiLogger,
    Dio? dio,
  }) async {
    if (logger != null) {
      NftCollection.logger = logger;
    }
    database = await $FloorNftCollectionDatabase
        .databaseBuilder(databaseFileName)
        .addMigrations(migrations)
        .build();
    prefs = NftCollectionPrefs(await SharedPreferences.getInstance());
    addressService = AddressService(database);

    tokenService = TokensServiceImpl(database, prefs, addressService, dio);
  }
}
