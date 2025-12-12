//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:path/path.dart' as p;

extension StringExtension on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';

  String snakeToCapital() => replaceAll('_', ' ').capitalize();

  String mask(int number) {
    if (isEmpty) {
      return '[]';
    } else if (length <= number) {
      return this;
    }
    return maskOnly(number);
  }

  String maskOnly(int number) {
    if (isEmpty) {
      return '';
    } else if (length <= number) {
      return this;
    }
    return '${substring(0, number)}...${substring(length - number, length)}';
  }

  String maskIfNeeded() {
    if (contains(' ')) {
      return this;
    }
    return (length >= 36) ? mask(4) : this;
  }

  String? toIdentityOrMask(Map<String, String>? identityMap) {
    if (isEmpty) {
      return null;
    }
    final identity = identityMap?[this];
    return (identity != null && identity.isNotEmpty)
        ? identity
        : maskIfNeeded();
  }

  bool isValidUrl() => Uri.tryParse(this) != null;

  bool isInvalidRPCScheme() => startsWith('file:') || startsWith('http:');

  String replacePrefix(String from, String to) {
    if (startsWith(from)) {
      return replaceRange(0, from.length, to);
    }
    return this;
  }

  String toUrl() {
    if (!startsWith('https://') && !startsWith('http://')) {
      return 'https://$this';
    }

    return this;
  }

  String? get blockchainForAddress {
    switch (length) {
      case 42:
        return 'ethereum';
      case 36:
        return 'tezos';
      default:
        return null;
    }
  }

  bool get isPostcardId {
    final splitted = split('-');
    return splitted.length > 1 &&
        splitted[1] == Environment.postcardContractAddress;
  }

  bool get isAutonomyDocumentLink =>
      (startsWith(AUTONOMY_DOCUMENT_PREFIX) ||
          startsWith(AUTONOMY_RAW_DOCUMENT_PREFIX)) &&
      endsWith(markdownExt);

  String get autonomyRawDocumentLink =>
      replaceFirst(AUTONOMY_DOCUMENT_PREFIX, AUTONOMY_RAW_DOCUMENT_PREFIX)
          .replaceFirst('/blob/', '/');

  String get toMimeType {
    final mimeType = this;
    switch (mimeType) {
      case 'image/avif':
      case 'image/bmp':
      case 'image/jpeg':
      case 'image/jpg':
      case 'image/png':
      case 'image/tiff':
        return RenderingType.image;

      case 'image/svg+xml':
        return RenderingType.svg;

      case 'image/gif':
        return RenderingType.gif;

      case 'audio/aac':
      case 'audio/midi':
      case 'audio/x-midi':
      case 'audio/mpeg':
      case 'audio/ogg':
      case 'audio/opus':
      case 'audio/wav':
      case 'audio/webm':
      case 'audio/3gpp':
      case 'audio/vnd.wave':
        return RenderingType.audio;

      case 'video/x-msvideo':
      case 'video/3gpp':
      case 'video/mp4':
      case 'video/mpeg':
      case 'video/ogg':
      case 'video/3gpp2':
      case 'video/quicktime':
      case 'application/x-mpegURL':
      case 'video/x-flv':
      case 'video/MP2T':
      case 'video/webm':
      case 'application/octet-stream':
        return RenderingType.video;

      case 'application/pdf':
        return RenderingType.pdf;

      case 'model/gltf-binary':
        return RenderingType.modelViewer;

      default:
        return RenderingType.webview;
    }
  }

  String get hexToDecimal => BigInt.parse(this, radix: 16).toString();

  bool get isDecimal => RegExp(r'^[0-9]+$').hasMatch(this);

  bool get isHex {
    String hexString = this;
    if (hexString.startsWith('0x')) {
      hexString = hexString.substring(2);
    }
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexString);
  }
}

extension UrlExtension on String {
  bool isSvgImage() {
    final ext = p.extension(this).toLowerCase();
    return ext == '.svg';
  }
}

extension SearchKeyExtension on String? {
  String get firstSearchCharacter {
    if (this == null || this!.isEmpty) {
      return '#';
    }
    if (listCharacters.contains(this![0].toUpperCase())) {
      return this![0].toUpperCase();
    }
    return '#';
  }

  int compareSearchKey(String? other) {
    final a = this ?? '';
    final b = other ?? '';
    final aFirstCharacter = firstSearchCharacter;
    final bFirstCharacter = other.firstSearchCharacter;
    if (aFirstCharacter == '#' && bFirstCharacter != '#') {
      return 1;
    }
    if (aFirstCharacter != '#' && bFirstCharacter == '#') {
      return -1;
    }
    return a.toUpperCase().compareTo(b.toUpperCase());
  }
}

extension ListStringExtension on List<String> {
  List<String> rotateListByItem(String item) {
    final index = indexOf(item);
    if (index == -1) {
      return this;
    }
    final newList = sublist(index)..addAll(sublist(0, index));
    return newList;
  }
}

final List<String> listCharacters = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '#'
];

extension JsonChunkExtractor on String {
  /// Trả về danh sách các JSON hoàn chỉnh và phần còn lại (chưa đủ JSON)
  /// Ví dụ:
  /// final (jsons, remain) = buffer.extractFullJsonChunks();
  (List<String>, String) extractFullJsonChunks() {
    List<String> jsons = [];
    int openBraces = 0;
    int startIndex = 0;
    for (int i = 0; i < length; i++) {
      if (this[i] == '{') openBraces++;
      if (this[i] == '}') openBraces--;
      if (openBraces == 0 && startIndex < i) {
        jsons.add(substring(startIndex, i + 1));
        startIndex = i + 1;
      }
    }
    return (jsons, substring(startIndex));
  }
}

extension StringUrlExtension on String {
  String get origin {
    final uri = Uri.tryParse(this);
    if (uri == null) {
      return this;
    }
    try {
      return uri.origin;
    } catch (e) {
      return '';
    }
  }
}

extension FeedUrlExtension on String {
  String? get playlistId {
    final uri = Uri.tryParse(this);
    if (uri == null) {
      return this;
    }
    return uri.pathSegments.lastOrNull;
  }

  String get channelId {
    final uri = Uri.tryParse(this);
    if (uri == null) {
      return this;
    }
    return uri.pathSegments.last;
  }
}
