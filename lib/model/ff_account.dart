// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //

// import 'package:json_annotation/json_annotation.dart';

// part 'ff_account.g.dart';

// @JsonSerializable()
// class FFContract {
//   FFContract(
//     this.name,
//     this.blockchainType,
//     this.address,
//   );

//   factory FFContract.fromJson(Map<String, dynamic> json) =>
//       _$FFContractFromJson(json);
//   final String name;
//   final String blockchainType;
//   final String address;

//   Map<String, dynamic> toJson() => _$FFContractToJson(this);
// }

// @JsonSerializable()
// class FeralfileError {
//   FeralfileError(
//     this.code,
//     this.message,
//   );

//   factory FeralfileError.fromJson(Map<String, dynamic> json) =>
//       _$FeralfileErrorFromJson(json);
//   final int code;
//   final String message;

//   Map<String, dynamic> toJson() => _$FeralfileErrorToJson(this);

//   @override
//   String toString() => 'FeralfileError{code: $code, message: $message}';
// }

// @JsonSerializable()
// class ResaleResponse {
//   ResaleResponse(this.result);

//   factory ResaleResponse.fromJson(Map<String, dynamic> json) =>
//       _$ResaleResponseFromJson(json);
//   final FeralFileResaleInfo result;

//   Map<String, dynamic> toJson() => _$ResaleResponseToJson(this);
// }

// @JsonSerializable()
// class FeralFileResaleInfo {
//   FeralFileResaleInfo(
//     this.exhibitionID,
//     this.saleType,
//     this.platform,
//     this.artist,
//     this.seller,
//     this.curator,
//     this.partner,
//     this.createdAt,
//     this.updatedAt,
//   );

//   factory FeralFileResaleInfo.fromJson(Map<String, dynamic> json) =>
//       _$FeralFileResaleInfoFromJson(json);
//   final String exhibitionID;
//   final String saleType;
//   final double platform;
//   final double artist;
//   final double seller;
//   final double curator;
//   final double partner;
//   final DateTime createdAt;
//   final DateTime updatedAt;

//   Map<String, dynamic> toJson() => _$FeralFileResaleInfoToJson(this);
// }

// class FileAssetMetadata {
//   FileAssetMetadata({required this.urlOverwrite});

//   // from Json method
//   factory FileAssetMetadata.fromJson(Map<String, dynamic> json) =>
//       FileAssetMetadata(urlOverwrite: json['urlOverwrite'] as String);
//   final String urlOverwrite;

//   // to Json method
//   Map<String, dynamic> toJson() => {
//         'urlOverwrite': urlOverwrite,
//       };
// }

// class FileInfo {
//   FileInfo({
//     required this.uri,
//     required this.status,
//     this.filename,
//     this.version,
//     this.metadata,
//     this.createdAt,
//     this.updatedAt,
//   });

//   // from Json method
//   factory FileInfo.fromJson(Map<String, dynamic> json) => FileInfo(
//         filename: json['filename'] as String?,
//         uri: json['uri'] as String,
//         status: json['status'] as String,
//         version: json['version'] as String?,
//         metadata: json['metadata'] == null ||
//                 (json['metadata'] as Map).isEmpty ||
//                 (json['metadata'] as Map<String, dynamic>)['urlOverwrite'] ==
//                     null
//             ? null
//             : FileAssetMetadata.fromJson(
//                 json['metadata'] as Map<String, dynamic>,
//               ),
//         createdAt: json['createdAt'] as String?,
//         updatedAt: json['updatedAt'] as String?,
//       );
//   final String? filename;
//   final String uri;
//   final String status;
//   final String? version;
//   final FileAssetMetadata? metadata;
//   final String? createdAt;
//   final String? updatedAt;

//   // to Json method
//   Map<String, dynamic> toJson() => {
//         'filename': filename,
//         'uri': uri,
//         'status': status,
//         'version': version,
//         'metadata': metadata?.toJson(),
//         'createdAt': createdAt,
//         'updatedAt': updatedAt,
//       };
// }
