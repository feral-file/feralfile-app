import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';

abstract class BaseCloudObject {
  BaseCloudObject(this.db);

  final CloudDB db;

  Future<void> download() async {
    await db.download();
  }

  void clearCache() {
    db.clearCache();
  }
}
