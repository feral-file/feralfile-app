import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:collection/collection.dart';

extension AssetTokenExtension on List<CompactedAssetToken> {
  List<CompactedAssetToken> filterAssetToken({bool isShowHidden = false}) {
    final hiddenTokens =
        injector<ConfigurationService>().getTempStorageHiddenTokenIDs();

    return whereNot(
      (element) =>
          (!isShowHidden && hiddenTokens.contains(element.id)) ||
          ((element.balance ?? 0) <= 0 && element.isDebugged != true),
    ).toList();
  }

  List<CompactedAssetToken> filterByTitleContain(String title) => where(
        (element) =>
            element.displayTitle!.toLowerCase().contains(title.toLowerCase()),
      ).toList();
}
