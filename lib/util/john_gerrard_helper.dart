import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';

class JohnGerrardHelper {
  static String? get contractAddress {
    final config =
        injector<RemoteConfigService>().getConfig<Map<String, dynamic>>(
      ConfigGroup.exhibition,
      ConfigKey.johnGerrard,
      {},
    );
    return config['contract_address'] as String?;
  }

  static String? get exhibitionID {
    final config =
        injector<RemoteConfigService>().getConfig<Map<String, dynamic>>(
      ConfigGroup.exhibition,
      ConfigKey.johnGerrard,
      {},
    );
    return config['exhibition_id'] as String?;
  }

  static List<dynamic> get seriesIDs {
    final listSeriesIds =
        injector<RemoteConfigService>().getConfig<List<dynamic>?>(
      ConfigGroup.johnGerrard,
      ConfigKey.seriesIds,
      [],
    );
    return listSeriesIds ?? [];
  }

  static List<String> get assetIDs {
    final listAssetIds =
        injector<RemoteConfigService>().getConfig<List<dynamic>?>(
      ConfigGroup.johnGerrard,
      ConfigKey.assetIds,
      [],
    );
    return List<String>.from(listAssetIds ?? []);
  }

  static String getIndexID(String tokenId) {
    final contractAddress = JohnGerrardHelper.contractAddress;
    return 'eth-$contractAddress-$tokenId';
  }

  static List<CustomExhibitionNote> get customNote {
    final listCustomNote =
        injector<RemoteConfigService>().getConfig<List<dynamic>?>(
      ConfigGroup.johnGerrard,
      ConfigKey.customNote,
      [],
    );
    return listCustomNote
            ?.map(
              (e) => CustomExhibitionNote.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList() ??
        [];
  }

  static List<String> disableKeys = ['i', 'g', 'm'];
}
