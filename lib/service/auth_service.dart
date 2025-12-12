import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:uuid/uuid.dart';

abstract class AuthService {
  Future<void> initialize();

  String? getUserId();

  Future<String> getOrGenerateUserId();
}

class AuthServiceImpl implements AuthService {
  late ConfigurationService _configurationService;

  AuthServiceImpl() {
    _configurationService = injector<ConfigurationService>();
  }

  String? _userId;

  @override
  Future<void> initialize() async {
    _userId = await _configurationService.getDeviceId();
  }

  @override
  String? getUserId() {
    return _userId;
  }

  String _generateUserId() {
    return const Uuid().v4();
  }

  Future<void> _setUserId(String userId) async {
    _userId = userId;
  }

  @override
  Future<String> getOrGenerateUserId() async {
    final userId = getUserId();
    if (userId != null) {
      return userId;
    }
    final newUserId = _generateUserId();
    await _setUserId(newUserId);
    return newUserId;
  }
}
