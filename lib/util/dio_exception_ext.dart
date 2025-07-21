import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:dio/dio.dart';

extension DioExceptionExt on DioException {
  String get data => response?.data as String? ?? '';

  String get dataMessage {
    if (response?.data is Map) {
      return (response?.data as Map)['message'] as String? ?? '';
    }
    return '';
  }

  int get statusCode => response?.statusCode ?? 0;

  int? get ffErrorCode => response?.data['error']['code'] as int?;

  bool get isAlreadySetReferralCode {
    if (response?.data is Map) {
      return response!.statusCode == 400 &&
          (response!.data as Map)['error']?['code'] == 3002;
    }
    return false;
  }
}

enum FeralFileErrorCode {
  // 1001 : token not found (expired)
  linkArtistTokenNotFound(1001),
  // 3006: the addresses have been linked to another accounts(users)
  linkArtistAddressAlreadyLinked(3006),
  // 3007: This user is having linked addresses already
  linkArtistUserAlreadyLinked(3007),
  passkeyUserNotExist(3008);

  final int code;

  const FeralFileErrorCode(this.code);
}

extension FeralfileErrorExt on FeralfileError {
  bool get isLinkArtistTokenNotFound {
    return code == FeralFileErrorCode.linkArtistTokenNotFound.code;
  }

  bool get isLinkArtistAddressAlreadyLinked {
    return code == FeralFileErrorCode.linkArtistAddressAlreadyLinked.code;
  }

  bool get isLinkArtistUserAlreadyLinked {
    return code == FeralFileErrorCode.linkArtistUserAlreadyLinked.code;
  }

  bool get isPasskeyUserNotExist {
    return code == FeralFileErrorCode.passkeyUserNotExist.code;
  }
}
