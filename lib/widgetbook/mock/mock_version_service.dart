import 'package:autonomy_flutter/model/release_note.dart';
import 'package:autonomy_flutter/service/versions_service.dart';

class MockVersionService implements VersionService {
  @override
  Future<void> checkForUpdate() async {
    return Future.value();
  }

  @override
  Future<List<ReleaseNote>> getReleaseNotes() {
    return Future.value([]);
  }

  @override
  Future<void> openLatestVersion() {
    return Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
