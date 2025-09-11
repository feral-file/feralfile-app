//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry/sentry.dart';

class Environment {
  static String _readKey(
    String key,
    String defaultValue, {
    bool isSecret = false,
  }) {
    final res = dotenv.env[key];
    if (res == null || res.isEmpty) {
      unawaited(Sentry.captureMessage('Environment variable $key is not set'));
      return defaultValue;
    }
    return res;
  }

  // check all the keys is set
  static void checkAllKeys() {
    const keys = [
      'REMOTE_CONFIG_URL',
      'TV_CAST_API_URL',
      'TOKEN_WEBVIEW_PREFIX',
      'INDEXER_MAINNET_API_URL',
      'INDEXER_TESTNET_API_URL',
      'WEB3_MAINNET_CHAIN_ID',
      'WEB3_RPC_TESTNET_URL',
      'WEB3_TESTNET_CHAIN_ID',
      'TEZOS_NODE_CLIENT_TESTNET_URL',
      'FERAL_FILE_API_MAINNET_URL',
      'FERAL_FILE_API_TESTNET_URL',
      'FERAL_FILE_ASSET_URL_TESTNET',
      'FERAL_FILE_ASSET_URL_MAINNET',
      'AUTONOMY_AUTH_URL',
      'CUSTOMER_SUPPORT_URL',
      'CURRENCY_EXCHANGE_URL',
      'AUTONOMY_PUBDOC_URL',
      'AUTONOMY_IPFS_PREFIX',
      'PENDING_TOKEN_EXPIRE_MS',
      // 'APP_TESTNET_CONFIG', ignore this key
      // 'IRL_WHITELIST_URL', // this key is not set
      'CLOUD_FLARE_IMAGE_URL_PREFIX',
      'TZKT_MAINNET_URL',
      'TZKT_TESTNET_URL',
      'ACCOUNT_SETTING_URL',
      'MOBILE_CONTROLLER_URL',
      'ARTBLOCKS_GRAPHQL_URL', // Add new key for Artblocks GraphQL URL
    ];
    const secretKeys = [
      'CHAT_SERVER_HMAC_KEY',
      'METRIC_SECRET_KEY',
      'AU_CLAIM_SECRET_KEY',
      'FERAL_FILE_SECRET_KEY_TESTNET',
      'FERAL_FILE_SECRET_KEY_MAINNET',
      'WEB3_RPC_MAINNET_URL',
      'SENTRY_DSN',
      'ONESIGNAL_APP_ID',
      'TV_API_KEY',
      'SUPPORT_API_KEY',
      'MOBILE_CONTROLLER_KEY',
    ];
    final missingKeys = <String>[];
    for (final key in keys) {
      if (_readKey(key, '') == '') {
        missingKeys.add(key);
      }
    }
    for (final key in secretKeys) {
      if (_readKey(key, '', isSecret: true) == '') {
        missingKeys.add(key);
      }
    }
    if (missingKeys.isNotEmpty) {
      unawaited(
        Sentry.captureMessage(
          'Environment variables are not set: ${missingKeys.join(', ')}',
        ),
      );
      unawaited(injector<NavigationService>().showEnvKeyIsMissing(missingKeys));
    }
  }

  static String get indexerURL =>
      appTestnetConfig ? indexerTestnetURL : indexerMainnetURL;

  static String get web3RpcURL =>
      appTestnetConfig ? web3RpcTestnetURL : web3RpcMainnetURL;

  static int get web3ChainId =>
      appTestnetConfig ? web3TestnetChainId : web3MainnetChainId;

  static String get feralFileAPIURL =>
      appTestnetConfig ? feralFileAPITestnetURL : feralFileAPIMainnetURL;

  static String get feralFileSecretKey =>
      appTestnetConfig ? feralFileSecretKeyTestnet : feralFileSecretKeyMainnet;

  static String get feralFileAssetURL =>
      appTestnetConfig ? feralFileAssetURLTestnet : feralFileAssetURLMainnet;

  static String get tvCastApiUrl => _readKey('TV_CAST_API_URL', '');

  static String get tvNotificationUrl => _readKey('TV_NOTIFICATION_URL', '');

  static String get tokenWebviewPrefix => _readKey('TOKEN_WEBVIEW_PREFIX', '');

  static String get indexerMainnetURL =>
      _readKey('INDEXER_MAINNET_API_URL', '');

  static String get indexerTestnetURL =>
      _readKey('INDEXER_TESTNET_API_URL', '');

  static int get web3MainnetChainId =>
      int.tryParse(_readKey('WEB3_MAINNET_CHAIN_ID', '1')) ?? 1;

  static String get web3RpcTestnetURL => _readKey('WEB3_RPC_TESTNET_URL', '');

  static int get web3TestnetChainId =>
      int.tryParse(_readKey('WEB3_TESTNET_CHAIN_ID', '5')) ?? 5;

  static String get tezosNodeClientTestnetURL =>
      _readKey('TEZOS_NODE_CLIENT_TESTNET_URL', '');

  static String get feralFileAPIMainnetURL =>
      _readKey('FERAL_FILE_API_MAINNET_URL', '');

  static String get feralFileAPITestnetURL =>
      _readKey('FERAL_FILE_API_TESTNET_URL', '');

  static String get feralFileAssetURLTestnet =>
      _readKey('FERAL_FILE_ASSET_URL_TESTNET', '');

  static String get feralFileAssetURLMainnet =>
      _readKey('FERAL_FILE_ASSET_URL_MAINNET', '');

  static String get autonomyAuthURL => _readKey('AUTONOMY_AUTH_URL', '');

  static String get customerSupportURL => _readKey('CUSTOMER_SUPPORT_URL', '');

  static String get currencyExchangeURL =>
      _readKey('CURRENCY_EXCHANGE_URL', '');

  static String get pubdocURL => _readKey('AUTONOMY_PUBDOC_URL', '');

  static String get remoteConfigURL => _readKey('REMOTE_CONFIG_URL', '');

  static String get autonomyIpfsPrefix => _readKey('AUTONOMY_IPFS_PREFIX', '');

  static int? get pendingTokenExpireMs =>
      int.tryParse(_readKey('PENDING_TOKEN_EXPIRE_MS', ''));

  static bool get appTestnetConfig =>
      _readKey('APP_TESTNET_CONFIG', '').toUpperCase() == 'TRUE';

  static List<String> get irlWhitelistUrls =>
      _readKey('IRL_WHITELIST_URL', '').split(',');

  static String get cloudFlareImageUrlPrefix =>
      _readKey('CLOUD_FLARE_IMAGE_URL_PREFIX', '');

  static String get postcardContractAddress =>
      _readKey('POSTCARD_CONTRACT_ADDRESS', '');

  static String get merchandiseBaseUrl =>
      _readKey('AUTONOMY_MERCHANDISE_BASE_URL', '');

  static String get merchandiseApiUrl =>
      _readKey('AUTONOMY_MERCHANDISE_API_URL', '');

  static String get payToMintBaseUrl => _readKey('PAY_TO_MINT_BASE_URL', '');

  static String get postcardChatServerUrl => _readKey('CHAT_SERVER_URL', '');

  static String get tzktMainnetURL => _readKey('TZKT_MAINNET_URL', '');

  static String get tzktTestnetURL => _readKey('TZKT_TESTNET_URL', '');

  static String get autonomyAirDropContractAddress =>
      _readKey('AUTONOMY_AIRDROP_CONTRACT_ADDRESS', '');

  static String get accountSettingUrl => _readKey('ACCOUNT_SETTING_URL', '');

  static String get domainResolverUrl => _readKey('DOMAIN_RESOLVER_URL', '');

  // secret keys
  static String get chatServerHmacKey =>
      _readKey('CHAT_SERVER_HMAC_KEY', '', isSecret: true);

  static String get metricSecretKey =>
      _readKey('METRIC_SECRET_KEY', '', isSecret: true);

  static String get auClaimSecretKey =>
      _readKey('AU_CLAIM_SECRET_KEY', '', isSecret: true);

  static String get feralFileSecretKeyTestnet =>
      _readKey('FERAL_FILE_SECRET_KEY_TESTNET', '', isSecret: true);

  static String get feralFileSecretKeyMainnet =>
      _readKey('FERAL_FILE_SECRET_KEY_MAINNET', '', isSecret: true);

  static String get web3RpcMainnetURL => _readKey(
        'WEB3_RPC_MAINNET_URL',
        '',
        isSecret: true,
      );

  static String get sentryDSN => _readKey('SENTRY_DSN', '', isSecret: true);

  static String get onesignalAppID =>
      _readKey('ONESIGNAL_APP_ID', '', isSecret: true);

  static String get tvKey => _readKey('TV_API_KEY', '', isSecret: true);

  static String get domainResolverApiKey =>
      _readKey('DOMAIN_RESOLVER_API_KEY', '', isSecret: true);

  static String get supportApiKey =>
      _readKey('SUPPORT_API_KEY', '', isSecret: true);

  //mobileControllerAPIURL
  static String get mobileControllerAPIURL =>
      _readKey('MOBILE_CONTROLLER_URL', '');

  static String get mobileControllerApiKey =>
      _readKey('MOBILE_CONTROLLER_KEY', '', isSecret: true);

  static String get dp1FeedUrl => _readKey('DP1_FEED_URL', '');

  static String get dp1FeedApiKey => _readKey(
        'DP1_FEED_API_KEY',
        '',
        isSecret: true,
      );

  // Artblocks GraphQL URL
  static String get artblocksGraphQLURL =>
      _readKey('ARTBLOCKS_GRAPHQL_URL', '');

  // MeiliSearch configuration
  static String get meiliSearchUrl => _readKey('MEILISEARCH_URL', '');
  static String get meiliSearchKey => _readKey('MEILISEARCH_KEY', '');
}
