import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';

class JohnGerrardHelper {
  static int _johnGerrardLatestRevealIndex = 0;

  static int get johnGerrardLatestRevealIndex => _johnGerrardLatestRevealIndex;

  static String? get contractAddress {
    final config =
        injector<RemoteConfigService>().getConfig<Map<String, dynamic>>(
      ConfigGroup.exhibition,
      ConfigKey.johnGerrard,
      {},
    );
    return config['contract_address'] as String?;
  }

  static List<String> disableKeys = ['i', 'g', 'm'];
}
