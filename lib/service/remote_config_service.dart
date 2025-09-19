import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/gateway/remote_config_api.dart';
import 'package:autonomy_flutter/util/log.dart';
//ignore_for_file: lines_longer_than_80_chars

abstract class RemoteConfigService {
  Future<void> loadConfigs({bool forceRefresh = false});

  bool getBool(final ConfigGroup group, final ConfigKey key);

  T getConfig<T>(final ConfigGroup group, final ConfigKey key, T defaultValue);

  bool get isLoaded;
}

class RemoteConfigServiceImpl implements RemoteConfigService {
  RemoteConfigServiceImpl(this._api);

  static const String keyRights = 'rights';
  final RemoteConfigApi _api;

  static Map<String, dynamic> _defaults = <String, dynamic>{
    'merchandise': {
      'enable': true,
      'allow_view_only': true,
      'must_complete': true,
      'postcard_tokenId_regex':
          r'^tez-KT1Rg1hhAPD8HSKaNKV6zuu7y8Zuk4QXaq2V-(1699413090857|1699951798888|1692601505415)$'
    },
    'pay_to_mint': {'enable': true, 'allow_view_only': true},
    'view_detail': {
      'action_button': true,
      'leader_board': true,
      'about_moma': true,
      'glossary': true,
      'metadata': true,
      'token_ownership': true,
      'provenance': true,
      'rights': true,
      'chat': true
    },
    'feature': {'download_stamp': true, 'download_postcard': true},
    'postcard_action': {'wait_confirmed_to_send': false},
    'feralfile_artwork_action': {
      'allow_download_artwork_contracts': [
        'KT19VkuK7tw22m4P36xRpPiMT4qzEw8YAN8A',
        'KT1CPeE8YGVG16xkpoE9sviUYoEzS7hWfu39',
        'KT1U49F46ZRK2WChpVpkUvwwQme7Z595V3nt',
        'KT19rZLpAurqKuDXtkMcJZWvWqGJz1CwWHzr',
        'KT1KzEtNm6Bb9qip8trTsnBohoriH2g2dvc7',
        'KT1RWFkvQPkhjxQQzg1ZvS2EKbprbkAdPRSc',
        'KT1X7i8EeQHChQ2cKGVthHrBS2jsPLSDWoEw'
      ],
      'sound_piece_contract_addresses': [
        '0x1d9787369b1dcf709f92da1d8743c2a4b6028a83'
      ],
      'yoko_ono_private_token_ids': [
        '5429577522081131997036023001590580143446575936',
        '5429577522081131997036023001590580143446575937',
        '5429577522081131997036023001590580143446575938',
        '5429577522081131997036023001590580143446575939',
        '5429577522081131997036023001590580143446575940',
        '5429577522081131997036023001590580143446575941',
        '5429577522081131997036023001590580143446575942',
        '5429577522081131997036023001590580143446575943',
        '5429577522081131997036023001590580143446575944',
        '5429577522081131997036023001590580143446575945',
        '5429577522081131997036023001590580143446575946',
        '5429577522081131997036023001590580143446575947',
        '5429577522081131997036023001590580143446575948',
        '5429577522081131997036023001590580143446575949',
        '5429577522081131997036023001590580143446575950',
        '5429577522081131997036023001590580143446575951',
        '5429577522081131997036023001590580143446575952',
        '5429577522081131997036023001590580143446575953',
        '5429577522081131997036023001590580143446575954',
        '5429577522081131997036023001590580143446575955',
        '5429577522081131997036023001590580143446575956',
        '5429577522081131997036023001590580143446575957',
        '5429577522081131997036023001590580143446575958',
        '5429577522081131997036023001590580143446575959',
        '5429577522081131997036023001590580143446575960',
        '5429577522081131997036023001590580143446575961',
        '5429577522081131997036023001590580143446575962',
        '5429577522081131997036023001590580143446575963',
        '5429577522081131997036023001590580143446575964',
        '5429577522081131997036023001590580143446575965'
      ],
      'scrollable_preview_url': null
    },
    'exhibition': {
      'specified_series_artwork_model_title': {
        'faa810f7-7b75-4c02-bf8a-b7447a89c921': 'interactive instruction'
      },
      'john_gerrard': {
        'contract_address': '0xBE0A4E26a156B2a60cF515E86b3Df9756DEE1952',
        'exhibition_id': '46a0f68b-a657-4364-92a0-32a88b65fbd9'
      },
      'crawl': {
        'exhibition_id': '3c4b0a8b-6d3e-4c32-aaae-c701bb9deca9',
        'merge_series_id': '0a954c31-d336-4e37-af0f-ec336c064879'
      },
      'dont_fake_artwork_series_ids': ['0a954c31-d336-4e37-af0f-ec336c064879'],
      'on_going_exhibition_ids': ['46a0f68b-a657-4364-92a0-32a88b65fbd9'],
      'foreword': {
        '796f9fd9-d405-451c-a584-d9f21222c6dd': [
          '<p>It’s unsurprising that evolution, the most potent and pervasive generative process we know, challenges our habits of thought. Richard Dawkins figured evolution as a <em>Blind Watchmaker</em>, embodying it in a fumbling pair of cosmic hands, even as he argued against intention or design. “Theory of mind” — our capacity to attribute and model the agency and motivations of others — seems to trip us up here. It’s hard to think about evolution without asking, <em>what does it want?</em></p>'
        ],
      }
    },
    'dApp_urls': {
      'deny_dApp_list': [],
      'tezos_nodes': [
        'https://mainnet.api.tez.ie',
        'https://rpc.tzbeta.net',
        'https://mainnet.smartpy.io',
        'https://mainnet.ecadinfra.com'
      ]
    },
    'in_app_webview': {
      'uri_scheme_white_list': ['https'],
      'allowed_fingerprints': [
        '04 2A 70 D1 55 FC 5A 92 B9 1B 20 E5 D7 FB 6A D0 54 05 76 30',
        '9D E0 F5 9B DC 83 6D 5D D5 4A 27 7A 80 C5 3D 3C AF 72 A7 DD',
        'C3 5E 95 D8 97 98 C2 81 A9 34 5F FA B0 EC F2 6F 4B 7D 1B 72',
        'DF 85 1C EE 81 FA 39 8E 54 E9 8E 9B BB 00 A7 DD D8 7B EC 0C',
        '49 EE 12 48 B5 B8 06 39 66 BC 8F 4F 1F FC 6D BE DD 06 35 99',
        '1E A8 0A 38 31 6B BA 28 D7 52 26 11 AC 32 F6 2A CA B1 B0 2C'
      ]
    },
    'john_gerrard': {
      'series_ids': [
        '0b95013a-599b-4af2-a0a4-fe13eff98e89',
        '4e7c1eba-7c17-4c38-9454-36c72ae98249'
      ],
      'asset_ids': [
        '0ae03302f46d0e110b7c40472a4badda40e78356a598f342dca036a012c003c9d128b8c61083e14076937e8706ba50f37b094761a94614347c'
      ]
    },
    'daily': {'scheduleTime': '6'},
    'video_settings': {
      'client_bandwidth_hint': null,
    },
    'local_cache_config': {
      'exhibition_last_updated': '2022-02-22T00:00:00Z',
      'featured_works_last_updated': '2022-02-22T00:00:00Z',
    },
    'tester': {
      'beta_tester': <String>[],
    },
    'dp1_playlist': {'channel_ids': null},
    ConfigGroup.documentation.name: {
      ConfigKey.docsUrl.name: 'https://docs.feralfile.com/ff1?from=app',
    },
  };

  static Map<String, dynamic>? _configs;
  bool _isLoading = false;

  @override
  bool get isLoaded => _configs != null;

  @override
  Future<void> loadConfigs({bool forceRefresh = false}) async {
    if ((_configs != null && !forceRefresh) || _isLoading) {
      return;
    }
    log.fine('RemoteConfigService: loadConfigs start');
    _isLoading = true;
    try {
      final data = await _api.getConfigs();
      _configs = jsonDecode(data) as Map<String, dynamic>;
      log.fine('RemoteConfigService: loadConfigs: $_configs');
    } catch (e) {
      log.warning('RemoteConfigService: loadConfigs: $e');
    } finally {
      _isLoading = false;
    }
  }

  @override
  bool getBool(final ConfigGroup group, final ConfigKey key) {
    if (_configs == null) {
      unawaited(loadConfigs());
      return _defaults[group.getString]![key.getString] as bool;
    } else {
      return _configs![group.getString]?[key.getString] as bool? ??
          _defaults[group.getString]?[key.getString] as bool? ??
          false;
    }
  }

  @override
  T getConfig<T>(final ConfigGroup group, final ConfigKey key, T defaultValue) {
    if (_configs == null) {
      unawaited(loadConfigs());
      return _defaults[group.getString]![key.getString] as T ?? defaultValue;
    } else {
      final hasKey = (_configs?.keys.contains(group.getString) ?? false) &&
          (_configs![group.getString] as Map<String, dynamic>)
              .keys
              .contains(key.getString);
      if (!hasKey) {
        final hasDefaultKey = _defaults.keys.contains(group.getString) &&
            (_defaults[group.getString] as Map<String, dynamic>)
                .keys
                .contains(key.getString);
        if (!hasDefaultKey) {
          log.warning('RemoteConfigService: getConfig: $group, $key not found');
          return defaultValue;
        }
        final res = _defaults[group.getString]![key.getString] as T;
        return res;
      }
      final res = _configs![group.getString]?[key.getString] as T;
      return res;
    }
  }
}

enum ConfigGroup {
  merchandise,
  payToMint,
  viewDetail,
  feature,
  postcardAction,
  feralfileArtworkAction,
  inAppWebView,
  dAppUrls,
  exhibition,
  johnGerrard,
  membership,
  daily,
  videoSettings,
  localCacheConfig,
  tester,
  dp1Playlist,
  documentation,
}

// ConfigGroup getString extension
extension ConfigGroupExtension on ConfigGroup {
  String get getString {
    switch (this) {
      case ConfigGroup.merchandise:
        return 'merchandise';
      case ConfigGroup.payToMint:
        return 'pay_to_mint';
      case ConfigGroup.viewDetail:
        return 'view_detail';
      case ConfigGroup.feature:
        return 'feature';
      case ConfigGroup.postcardAction:
        return 'postcard_action';
      case ConfigGroup.feralfileArtworkAction:
        return 'feralfile_artwork_action';
      case ConfigGroup.inAppWebView:
        return 'in_app_webview';
      case ConfigGroup.dAppUrls:
        return 'dApp_urls';
      case ConfigGroup.exhibition:
        return 'exhibition';
      case ConfigGroup.johnGerrard:
        return 'john_gerrard';
      case ConfigGroup.membership:
        return 'membership';
      case ConfigGroup.daily:
        return 'daily';
      case ConfigGroup.videoSettings:
        return 'video_settings';
      case ConfigGroup.localCacheConfig:
        return 'local_cache_config';
      case ConfigGroup.tester:
        return 'tester';
      case ConfigGroup.dp1Playlist:
        return 'dp1_playlist';
      case ConfigGroup.documentation:
        return 'documentation';
    }
  }
}

enum ConfigKey {
  enable,
  allowViewOnly,
  mustCompleted,
  postcardTokenIdRegex,
  actionButton,
  leaderBoard,
  aboutMoma,
  glossary,
  metadata,
  tokenOwnership,
  provenance,
  rights,
  downloadStamp,
  downloadPostcard,
  chat,
  waitConfirmedToSend,
  allowDownloadArtworkContracts,
  soundPieceContractAddresses,
  scrollablePreviewUrl,
  specifiedSeriesArtworkModelTitle,
  johnGerrard,
  crawl,
  dontFakeArtworkSeriesIds,
  ongoingExhibitionIDs,
  yokoOnoPrivateTokenIds,
  uriSchemeWhiteList,
  denyDAppList,
  allowedFingerprints,
  tezosNodes,
  seriesIds,
  assetIds,
  customNote,
  lifetime,
  scheduleTime,
  clientBandwidthHint,
  exhibitionLastUpdated,
  featuredWorksLastUpdated,
  foreWord,
  betaTester,
  dp1PlaylistChannelIds,
  docsUrl,
}

// ConfigKey getString extension
extension ConfigKeyExtension on ConfigKey {
  String get getString {
    switch (this) {
      case ConfigKey.enable:
        return 'enable';
      case ConfigKey.allowViewOnly:
        return 'allow_view_only';
      case ConfigKey.mustCompleted:
        return 'must_complete';
      case ConfigKey.postcardTokenIdRegex:
        return 'postcard_tokenId_regex';
      case ConfigKey.actionButton:
        return 'action_button';
      case ConfigKey.leaderBoard:
        return 'leader_board';
      case ConfigKey.aboutMoma:
        return 'about_moma';
      case ConfigKey.glossary:
        return 'glossary';
      case ConfigKey.metadata:
        return 'metadata';
      case ConfigKey.tokenOwnership:
        return 'token_ownership';
      case ConfigKey.provenance:
        return 'provenance';
      case ConfigKey.rights:
        return 'rights';
      case ConfigKey.downloadStamp:
        return 'download_stamp';
      case ConfigKey.downloadPostcard:
        return 'download_postcard';
      case ConfigKey.chat:
        return 'chat';
      case ConfigKey.waitConfirmedToSend:
        return 'wait_confirmed_to_send';
      case ConfigKey.allowDownloadArtworkContracts:
        return 'allow_download_artwork_contracts';
      case ConfigKey.soundPieceContractAddresses:
        return 'sound_piece_contract_addresses';
      case ConfigKey.scrollablePreviewUrl:
        return 'scrollable_preview_url';
      case ConfigKey.specifiedSeriesArtworkModelTitle:
        return 'specified_series_artwork_model_title';
      case ConfigKey.johnGerrard:
        return 'john_gerrard';
      case ConfigKey.crawl:
        return 'crawl';
      case ConfigKey.dontFakeArtworkSeriesIds:
        return 'dont_fake_artwork_series_ids';
      case ConfigKey.ongoingExhibitionIDs:
        return 'on_going_exhibition_ids';
      case ConfigKey.yokoOnoPrivateTokenIds:
        return 'yoko_ono_private_token_ids';
      case ConfigKey.uriSchemeWhiteList:
        return 'uri_scheme_white_list';
      case ConfigKey.denyDAppList:
        return 'deny_dApp_list';
      case ConfigKey.allowedFingerprints:
        return 'allowed_fingerprints';
      case ConfigKey.tezosNodes:
        return 'tezos_nodes';
      case ConfigKey.seriesIds:
        return 'series_ids';
      case ConfigKey.assetIds:
        return 'asset_ids';
      case ConfigKey.customNote:
        return 'custom_notes';
      case ConfigKey.lifetime:
        return 'lifetime';
      case ConfigKey.scheduleTime:
        return 'scheduleTime';
      case ConfigKey.clientBandwidthHint:
        return 'client_bandwidth_hint';
      case ConfigKey.exhibitionLastUpdated:
        return 'exhibition_last_updated';
      case ConfigKey.featuredWorksLastUpdated:
        return 'featured_works_last_updated';
      case ConfigKey.foreWord:
        return 'foreword';
      case ConfigKey.betaTester:
        return 'beta_tester';
      case ConfigKey.dp1PlaylistChannelIds:
        return 'channel_ids';
      case ConfigKey.docsUrl:
        return 'docs_url';
    }
  }
}
