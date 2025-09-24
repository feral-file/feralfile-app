import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const objectboxDBFile = 'com.bitmark.feralfile.db';

class ObjectBox {
  /// The Store of this app.
  static late Store store;

  ObjectBox._create(Store storeInstance) {
    store = storeInstance;
  }

  static Future<ObjectBox> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store =
        await openStore(directory: p.join(docsDir.path, objectboxDBFile));
    return ObjectBox._create(store);
  }

  static Future<void> removeAll() async {}
}
