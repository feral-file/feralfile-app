import 'dart:convert';

import 'package:autonomy_flutter/model/base_object.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum PlayListSource {
  manual,
  auto,
  activation;

  // from String
  static PlayListSource fromString(String value) {
    switch (value) {
      case 'manual':
        return PlayListSource.manual;
      case 'auto':
        return PlayListSource.auto;
      case 'activation':
        return PlayListSource.activation;
      default:
        return PlayListSource.manual;
    }
  }

  // to String
  String get value {
    switch (this) {
      case PlayListSource.manual:
        return 'manual';
      case PlayListSource.auto:
        return 'auto';
      case PlayListSource.activation:
        return 'activation';
    }
  }
}

class PlayListModel implements BaseObject {
  String id;
  String? name;
  String? thumbnailURL;
  List<String> tokenIDs;
  String? shareUrl;
  final PlayListSource source;

  PlayListModel({
    required this.tokenIDs,
    String? id,
    this.name,
    this.thumbnailURL,
    this.shareUrl,
    this.source = PlayListSource.manual,
  }) : id = id ?? const Uuid().v4();

  PlayListModel copyWith({
    String? id,
    String? name,
    String? thumbnailURL,
    List<String>? tokenIDs,
    String? shareUrl,
    PlayListSource? source,
  }) =>
      PlayListModel(
        id: id ?? this.id,
        name: name ?? this.name,
        thumbnailURL: thumbnailURL ?? this.thumbnailURL,
        tokenIDs: tokenIDs ?? this.tokenIDs,
        shareUrl: shareUrl ?? this.shareUrl,
        source: source ?? this.source,
      );

  @override
  String toString() =>
      'PlayListModel(id: $id, name: $name, thumbnailURL: $thumbnailURL, '
      'tokenIDs: $tokenIDs, shareUrl: $shareUrl, source: $source)';

  @override
  bool operator ==(covariant PlayListModel other) {
    if (identical(this, other)) {
      return true;
    }

    return other.id == id &&
        other.name == name &&
        other.thumbnailURL == thumbnailURL &&
        listEquals(other.tokenIDs, tokenIDs);
  }

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ thumbnailURL.hashCode ^ tokenIDs.hashCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'thumbnailURL': thumbnailURL,
        'tokenIDs': tokenIDs,
        'shareUrl': shareUrl,
        'source': source.value,
      };

  factory PlayListModel.fromJson(Map<String, dynamic> map) => PlayListModel(
        id: map['id'] != null ? map['id'] as String : const Uuid().v4(),
        name: map['name'] != null ? map['name'] as String : null,
        thumbnailURL:
            map['thumbnailURL'] != null ? map['thumbnailURL'] as String : null,
        tokenIDs: map['tokenIDs'] != null
            ? List<String>.from(map['tokenIDs'] as List<dynamic>)
            : [],
        shareUrl: map['shareUrl'] != null ? map['shareUrl'] as String : null,
        source: map['source'] != null
            ? PlayListSource.fromString(map['source'] as String)
            : PlayListSource.manual,
      );

  String getName() => name ?? tr('untitled');

  @override
  String get key => id;

  @override
  Map<String, String> get toKeyValue => {
        'key': key,
        'value': value,
      };

  @override
  String get value => jsonEncode(toJson());
}

extension PlayListModelExtension on PlayListModel {
  bool get isDefault {
    final defaultPlaylists = DefaultPlaylistModel.getAll();
    return defaultPlaylists.any((element) => element.id == id);
  }
}

enum DefaultPlaylistModel {
  allNfts;

  String get id {
    switch (this) {
      case DefaultPlaylistModel.allNfts:
        return 'all_nfts';
    }
  }

  String get name {
    switch (this) {
      case DefaultPlaylistModel.allNfts:
        return 'all'.tr();
    }
  }

  static List<DefaultPlaylistModel> getAll() => [
        DefaultPlaylistModel.allNfts,
      ];
}
