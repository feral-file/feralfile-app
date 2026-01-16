import 'dart:convert';

import 'package:autonomy_flutter/model/base_object.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/string_ext.dart';

class WalletAddress implements BaseObject {
  WalletAddress({
    required this.address,
    required this.createdAt,
    this.isHidden = false,
    String? name,
  }) : name = name?.maskIfNeeded() ?? CryptoType.fromAddress(address).name;

  // fromJson and toJson methods
  factory WalletAddress.fromJson(Map<String, dynamic> json) => WalletAddress(
        address: json['address'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isHidden: json['isHidden'] as bool,
        name: json['name'] as String?,
      );

  final String address;
  final DateTime createdAt;
  final bool isHidden;
  final String name;

  WalletAddress copyWith({
    String? address,
    String? cryptoType,
    DateTime? createdAt,
    bool? isHidden,
    String? name,
  }) =>
      WalletAddress(
        address: address ?? this.address,
        createdAt: createdAt ?? this.createdAt,
        isHidden: isHidden ?? this.isHidden,
        name: name ?? this.name,
      );

  AddressIndex get addressIndex =>
      AddressIndex(address: address, createdAt: createdAt);

  Map<String, dynamic> toJson() => {
        'address': address,
        'createdAt': createdAt.toIso8601String(),
        'isHidden': isHidden,
        'name': name,
      };

  @override
  String get key => address;

  @override
  Map<String, String> get toKeyValue => {
        'key': key,
        'value': value,
      };

  @override
  String get value => jsonEncode(toJson());

  CryptoType get cryptoType {
    return CryptoType.fromAddress(address);
  }
}
