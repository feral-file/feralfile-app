//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/list_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

//ignore_for_file: constant_identifier_names

abstract class ConfigurationService {
  int getDailyLikedCount();

  Future<void> setDailyLikedCount(int count);

  Future<String> getDeviceId();

  List<String> getAnonymousIssueIds();

  Future<void> addAnonymousIssueId(List<String> issueIds);

  Future<void> setLastPullAnnouncementTime(int lastPullTime);

  int getLastPullAnnouncementTime();

  Future<void> setAnnouncementLastPullTime(int lastPullTime);

  int? getAnnouncementLastPullTime();

  Future<void> setOldUser();

  bool getIsOldUser();

  Future<void> setDoneOnboarding(bool value);

  bool isDoneOnboarding();

  Future<void> setReadReleaseNotesInVersion(String version);

  String? getReadReleaseNotesVersion();

  String? getPreviousBuildNumber();

  Future<void> setPreviousBuildNumber(String value);

  Future<String> getAccountHMACSecret();

  String? lastRemindReviewDate();

  Future<void> setLastRemindReviewDate(String? value);

  int? countOpenApp();

  Future<void> setCountOpenApp(int? value);

  // ----- App Setting -----

  bool showTokenDebugInfo();

  Future<void> setShowTokenDebugInfo(bool show);

  Future<void> setDoneOnboardingTime(DateTime time);

  // Reload
  Future<void> reload();

  Future<void> removeAll();

  ValueNotifier<bool> get showingNotification;

  String getVersionInfo();

  Future<void> setVersionInfo(String version);

  bool getShowAddAddressBanner();

  void setLinkAnnouncementToIssue(String announcementContentId, String issueId);

  String? getIssueIdByAnnouncementContentId(String announcementContentId);

  String? getAnnouncementContentIdByIssueId(String issueId);

  bool isBetaTester();

  Future<void> setBetaTester(bool value);

  String? getPilotVersion();

  Future<void> setPilotVersion(String version);

  List<String> getRecordedMessages();

  Future<void> addRecordedMessage(String message);

  Future<void> setRecordedMessages(List<String> messages);

  Future<void> setAddressLastFetchTokenTime(Map<String, DateTime> time);

  Map<String, DateTime> getAddressLastFetchTokenTime();

  Future<void> clearAddressLastFetchTokenTime();

  bool hasSeenPlayToFf1Tooltip();

  Future<void> setHasSeenPlayToFf1Tooltip(bool value);

  DateTime? getLastTimeRefreshFeeds();
  Future<void> setLastTimeRefreshFeeds(DateTime time);

  /// Per-feed-service last refresh time keyed by DP1 feed baseUrl.
  ///
  /// This allows each DP1 feed service to decide its own cache reload policy
  /// instead of relying on the global [getLastTimeRefreshFeeds] value.
  Map<String, DateTime> getDp1LastTimeRefreshFeedsByUrl();

  Future<void> setDp1LastTimeRefreshFeedsByUrl(
      Map<String, DateTime> lastRefreshByUrl);

  /// Delete last refresh time for a specific DP1 feed service by URL.
  Future<void> deleteDp1LastTimeRefreshFeedByUrl(String url);

  DateTime? getLastUpdateChangeAt();

  Future<void> setLastUpdateChangeAt(DateTime time);

  List<AddressAnchor> getLastUpdateChangeAnchor({
    required List<String> addresses,
    AddressAnchor Function(String address)? defaultAnchorBuilder,
  });

  Future<void> setLastUpdateChangeAnchor({
    required List<AddressAnchor> addressAnchors,
  });

  String? getDismissedFirmwareUpdateVersion();

  Future<void> setDismissedFirmwareUpdateVersion(String? version);

  /// Address indexing info (per-address workflow and related metadata)
  Future<void> setAddressIndexingInfo(List<AddressIndexingInfo> infos);

  List<AddressIndexingInfo> getAddressIndexingInfo();

  Future<void> clearAddressIndexingInfo();
}

class ConfigurationServiceImpl implements ConfigurationService {
  ConfigurationServiceImpl(this._preferences);

  static const int _version = 1;

  static const String keyDailyLikedCount = 'daily_liked_count';
  static const String keyDeviceId = 'device_id';
  static const String keyAnonymousIssueIds = 'anonymous_issue_ids';
  static const String keyLastPullAnnouncementTime =
      'last_pull_announcement_time';
  static const String KEY_HAS_MERCHANDISE_SUPPORT_INDEX_ID =
      'has_merchandise_support';
  static const String KEY_POSTCARD_CHAT_CONFIG = 'postcard_chat_config';
  static const String KEY_HIDDEN_FEEDS = 'hidden_feeds';
  static const String IS_PREMIUM = 'is_premium';
  static const String KEY_DONE_ONBOARING = 'done_onboarding_v2';
  static const String KEY_LAST_TIME_ASK_SUBSCRIPTION =
      'last_time_ask_subscription';
  static const String KEY_RECENTLY_SENT_TOKEN = 'recently_sent_token_mainnet';
  static const String KEY_READ_RELEASE_NOTES_VERSION =
      'read_release_notes_version';
  static const String ACCOUNT_HMAC_SECRET = 'account_hmac_secret';
  static const String KEY_SHARED_POSTCARD = 'shared_postcard';

  static const String ANNOUNCEMENT_LAST_PULL_TIME =
      'announcement_last_pull_time';
  static const String OLD_USER = 'old_user';

  static const String DID_RUN_SETUP = 'did_run_setup';

  static const String KEY_ANNOUNCEMENT_TO_ISSUE_MAP =
      'announcement_to_issue_map';

  // ----- App Setting -----
  static const String KEY_PREVIOUS_BUILD_NUMBER = 'previous_build_number';
  static const String KEY_SHOW_TOKEN_DEBUG_INFO = 'show_token_debug_info';
  static const String LAST_REMIND_REVIEW = 'last_remind_review';
  static const String COUNT_OPEN_APP = 'count_open_app';
  static const String ALLOW_CONTRIBUTION = 'allow_contribution';

  static const String SHOW_AU_CHAIN_INFO = 'show_au_chain_info';

  static const String KEY_DONE_ON_BOARDING_TIME = 'done_on_boarding_time';

  static const String KEY_SUBSCRIPTION_TIME = 'subscription_time';

  static const String KEY_STAMPING_POSTCARD = 'stamping_postcard';

  static const String KEY_AUTO_SHOW_POSTCARD = 'auto_show_postcard';

  static const String KEY_ALREADY_SHOW_YOU_DID_IT_POSTCARD =
      'already_show_you_did_it_postcard';

  static const String KEY_CURRENT_GROUP_CHAT_ID = 'current_group_chat_id';

  static const String KEY_ALREADY_SHOW_POSTCARD_UPDATES =
      'already_show_postcard_updates';

  static const String KEY_MIXPANEL_PROPS = 'mixpanel_props';

  static const String KEY_PACKAGE_INFO = 'package_info';

  static const String KEY_PROCESSING_STAMP_POSTCARD =
      'processing_stamp_postcard';

  static const String KEY_SHOW_POSTCARD_BANNER = 'show_postcard_banner';

  static const String KEY_SHOW_ADD_ADDRESS_BANNER = 'show_add_address_banner';

  static const String KEY_MERCHANDISE_ORDER_IDS = 'merchandise_order_ids';

  static const String LAST_CONNECTED_DEVICE = 'last_connected_device';

  static const String KEY_BETA_TESTER = 'beta_tester';

  static const String PILOT_VERSION = 'pilot_version';

  static const String KEY_ADDRESS_LAST_FETCH_TOKEN_TIME =
      'address_last_fetch_token_time$_version';

  static const String KEY_LAST_UPDATE_CHANGE_ANCHOR =
      'last_update_change_anchor$_version';

  static const String KEY_LAST_TIME_REFRESH_FEEDS =
      'last_time_refresh_feeds$_version';

  /// Map<String, String> JSON storing per-feed-service last refresh times,
  /// keyed by DP1 feed baseUrl and ISO8601 timestamps as values.
  ///
  /// This is used by DP1 feed services to decide if they should reload cache
  /// individually instead of relying on the legacy global
  /// [KEY_LAST_TIME_REFRESH_FEEDS] value.
  static const String KEY_DP1_LAST_TIME_REFRESH_FEEDS_BY_URL =
      'dp1_last_time_refresh_feeds_by_url$_version';

  static const String KEY_LAST_UPDATE_CHANGE_AT =
      'last_update_change_at$_version';

  static const String POSTCARD_MINT = 'postcard_mint';

  static const String KEY_RECORDED_MESSAGES = 'recorded_messages';

  static const String KEY_HAS_SEEN_PLAY_TO_FF1_TOOLTIP =
      'has_seen_play_to_ff1_tooltip';
  static const String KEY_DISMISSED_FIRMWARE_UPDATE_VERSION =
      'dismissed_firmware_update_version';

  static const String KEY_ADDRESS_INDEXING_INFO =
      'address_indexing_info$_version';

  final SharedPreferences _preferences;

  @override
  bool isDoneOnboarding() => _preferences.getBool(KEY_DONE_ONBOARING) ?? false;

  @override
  Future<void> setDoneOnboarding(bool value) async {
    log.info('setDoneOnboarding: $value');
    final currentValue = isDoneOnboarding();
    await _preferences.setBool(KEY_DONE_ONBOARING, value);

    if (!currentValue && value && !getIsOldUser()) {
      await setDoneOnboardingTime(DateTime.now());
      await setOldUser();
    }
  }

  @override
  Future<void> setReadReleaseNotesInVersion(String version) async {
    await _preferences.setString(KEY_READ_RELEASE_NOTES_VERSION, version);
  }

  @override
  String? getReadReleaseNotesVersion() =>
      _preferences.getString(KEY_READ_RELEASE_NOTES_VERSION);

  @override
  Future<void> reload() => _preferences.reload();

  @override
  Future<void> setPreviousBuildNumber(String value) async {
    await _preferences.setString(KEY_PREVIOUS_BUILD_NUMBER, value);
  }

  @override
  String? getPreviousBuildNumber() =>
      _preferences.getString(KEY_PREVIOUS_BUILD_NUMBER);

  @override
  Future<String> getAccountHMACSecret() async {
    final value = _preferences.getString(ACCOUNT_HMAC_SECRET);
    if (value == null) {
      final setValue = const Uuid().v4();
      await _preferences.setString(ACCOUNT_HMAC_SECRET, setValue);
      return setValue;
    }

    return value;
  }

  @override
  bool showTokenDebugInfo() =>
      _preferences.getBool(KEY_SHOW_TOKEN_DEBUG_INFO) ?? false;

  @override
  Future<void> setShowTokenDebugInfo(bool show) async {
    await _preferences.setBool(KEY_SHOW_TOKEN_DEBUG_INFO, show);
  }

  @override
  bool hasSeenPlayToFf1Tooltip() =>
      _preferences.getBool(KEY_HAS_SEEN_PLAY_TO_FF1_TOOLTIP) ?? false;

  @override
  Future<void> setHasSeenPlayToFf1Tooltip(bool value) async {
    await _preferences.setBool(KEY_HAS_SEEN_PLAY_TO_FF1_TOOLTIP, value);
  }

  @override
  Future<void> removeAll() => _preferences.clear();

  @override
  String? lastRemindReviewDate() => _preferences.getString(LAST_REMIND_REVIEW);

  @override
  Future<void> setLastRemindReviewDate(String? value) async {
    if (value == null) {
      await _preferences.remove(LAST_REMIND_REVIEW);
      return;
    }
    await _preferences.setString(LAST_REMIND_REVIEW, value);
  }

  @override
  int? countOpenApp() => _preferences.getInt(COUNT_OPEN_APP);

  @override
  Future<void> setCountOpenApp(int? value) async {
    if (value == null) {
      await _preferences.remove(COUNT_OPEN_APP);
      return;
    }
    await _preferences.setInt(COUNT_OPEN_APP, value);
  }

  @override
  int? getAnnouncementLastPullTime() =>
      _preferences.getInt(ANNOUNCEMENT_LAST_PULL_TIME);

  @override
  Future<void> setAnnouncementLastPullTime(int lastPullTime) async {
    await _preferences.setInt(ANNOUNCEMENT_LAST_PULL_TIME, lastPullTime);
  }

  @override
  bool getIsOldUser() => _preferences.getBool(OLD_USER) ?? false;

  @override
  Future<void> setOldUser() async {
    await _preferences.setBool(OLD_USER, true);
  }

  @override
  ValueNotifier<bool> showingNotification = ValueNotifier(false);

  @override
  Future<void> setDoneOnboardingTime(DateTime time) async {
    await _preferences.setString(
      KEY_DONE_ON_BOARDING_TIME,
      time.toIso8601String(),
    );
  }

  @override
  String getVersionInfo() => _preferences.getString(KEY_PACKAGE_INFO) ?? '';

  @override
  Future<void> setVersionInfo(String version) async {
    await _preferences.setString(KEY_PACKAGE_INFO, version);
  }

  @override
  bool getShowAddAddressBanner() =>
      _preferences.getBool(KEY_SHOW_ADD_ADDRESS_BANNER) ?? true;

  @override
  int getLastPullAnnouncementTime() =>
      _preferences.getInt(keyLastPullAnnouncementTime) ?? 0;

  @override
  Future<void> setLastPullAnnouncementTime(int lastPullTime) =>
      _preferences.setInt(keyLastPullAnnouncementTime, lastPullTime);

  @override
  String? getAnnouncementContentIdByIssueId(String issueId) {
    final map = _preferences.getString(KEY_ANNOUNCEMENT_TO_ISSUE_MAP);
    if (map == null) {
      return null;
    }
    final mapJson = jsonDecode(map) as Map<String, dynamic>;
    return mapJson.entries
        .firstWhereOrNull((element) => element.value == issueId)
        ?.key;
  }

  @override
  String? getIssueIdByAnnouncementContentId(String announcementContentId) {
    final map = _preferences.getString(KEY_ANNOUNCEMENT_TO_ISSUE_MAP);
    if (map == null) {
      return null;
    }
    final mapJson = jsonDecode(map) as Map<String, dynamic>;
    return mapJson[announcementContentId] as String?;
  }

  @override
  Future<void> setLinkAnnouncementToIssue(
    String announcementContentId,
    String issueId,
  ) async {
    final map = _preferences.getString(KEY_ANNOUNCEMENT_TO_ISSUE_MAP);
    final mapJson = map == null ? <String, String>{} : jsonDecode(map);
    mapJson[announcementContentId] = issueId;
    await _preferences.setString(
      KEY_ANNOUNCEMENT_TO_ISSUE_MAP,
      jsonEncode(mapJson),
    );
  }

  Future<String> createDeviceId() async {
    final uuid = const Uuid().v4();
    await _preferences.setString(keyDeviceId, uuid);
    return uuid;
  }

  @override
  Future<String> getDeviceId() async {
    return _preferences.getString(keyDeviceId) ?? createDeviceId();
  }

  @override
  Future<void> addAnonymousIssueId(List<String> issueIds) {
    final currentIssueIds = getAnonymousIssueIds()
      ..addAll(issueIds)
      ..unique();
    return _preferences.setStringList(keyAnonymousIssueIds, currentIssueIds);
  }

  @override
  List<String> getAnonymousIssueIds() =>
      _preferences.getStringList(keyAnonymousIssueIds) ?? <String>[];

  @override
  int getDailyLikedCount() => _preferences.getInt(keyDailyLikedCount) ?? 0;

  @override
  Future<void> setDailyLikedCount(int count) async {
    await _preferences.setInt(keyDailyLikedCount, count);
  }

  @override
  bool isBetaTester() {
    return _preferences.getBool(KEY_BETA_TESTER) ?? false;
  }

  @override
  Future<void> setBetaTester(bool value) {
    return _preferences.setBool(KEY_BETA_TESTER, value);
  }

  @override
  String? getPilotVersion() {
    return _preferences.getString(PILOT_VERSION);
  }

  @override
  Future<void> setPilotVersion(String version) {
    return _preferences.setString(PILOT_VERSION, version);
  }

  @override
  List<String> getRecordedMessages() =>
      _preferences.getStringList(KEY_RECORDED_MESSAGES) ?? [];

  @override
  Future<void> addRecordedMessage(String message) async {
    var currentMessages = getRecordedMessages();
    if (currentMessages.length >= 20) {
      currentMessages = currentMessages.sublist(0, 19);
    }

    currentMessages.insert(0, message);
    await setRecordedMessages(currentMessages);
  }

  @override
  Future<void> setRecordedMessages(List<String> messages) async {
    await _preferences.setStringList(KEY_RECORDED_MESSAGES, messages);
  }

  @override
  Future<void> clearAddressLastFetchTokenTime() {
    return _preferences.remove(KEY_ADDRESS_LAST_FETCH_TOKEN_TIME);
  }

  @override
  Map<String, DateTime> getAddressLastFetchTokenTime() {
    final time = _preferences.getString(KEY_ADDRESS_LAST_FETCH_TOKEN_TIME);
    if (time == null) {
      return {};
    }
    final timeJson = jsonDecode(time) as Map<String, dynamic>;
    return timeJson
        .map((key, value) => MapEntry(key, DateTime.parse(value as String)));
  }

  @override
  Future<void> setAddressLastFetchTokenTime(Map<String, DateTime> time) {
    final timeJson =
        time.map((key, value) => MapEntry(key, value.toIso8601String()));
    return _preferences.setString(
      KEY_ADDRESS_LAST_FETCH_TOKEN_TIME,
      jsonEncode(timeJson),
    );
  }

  @override
  DateTime? getLastTimeRefreshFeeds() {
    final time = _preferences.getString(KEY_LAST_TIME_REFRESH_FEEDS);
    if (time == null) {
      return null;
    }
    return DateTime.parse(time);
  }

  @override
  Future<void> setLastTimeRefreshFeeds(DateTime time) => _preferences.setString(
        KEY_LAST_TIME_REFRESH_FEEDS,
        time.toIso8601String(),
      );

  @override
  Map<String, DateTime> getDp1LastTimeRefreshFeedsByUrl() {
    final raw = _preferences.getString(KEY_DP1_LAST_TIME_REFRESH_FEEDS_BY_URL);
    if (raw == null) {
      // Backward compatibility: if per-url map is not set yet, but the
      // legacy global last-refresh value exists, expose it as an empty map
      // and let services set their own timestamps after first successful
      // reload. We deliberately do NOT try to fan out the single value to
      // all URLs here to keep behavior simple and explicit.
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        DateTime.parse(value as String),
      ),
    );
  }

  @override
  Future<void> setDp1LastTimeRefreshFeedsByUrl(
    Map<String, DateTime> lastRefreshByUrl,
  ) {
    final encoded = lastRefreshByUrl.map(
      (key, value) => MapEntry(
        key,
        value.toIso8601String(),
      ),
    );
    return _preferences.setString(
      KEY_DP1_LAST_TIME_REFRESH_FEEDS_BY_URL,
      jsonEncode(encoded),
    );
  }

  @override
  Future<void> deleteDp1LastTimeRefreshFeedByUrl(String url) async {
    final currentMap = getDp1LastTimeRefreshFeedsByUrl();
    currentMap.remove(url);
    await setDp1LastTimeRefreshFeedsByUrl(currentMap);
  }

  @override
  DateTime? getLastUpdateChangeAt() {
    final time = _preferences.getString(KEY_LAST_UPDATE_CHANGE_AT);
    if (time == null) {
      return null;
    }
    return DateTime.parse(time);
  }

  @override
  Future<void> setLastUpdateChangeAt(DateTime time) =>
      _preferences.setString(KEY_LAST_UPDATE_CHANGE_AT, time.toIso8601String());

  @override
  List<AddressAnchor> getLastUpdateChangeAnchor({
    required List<String> addresses,
    AddressAnchor Function(String address)? defaultAnchorBuilder,
  }) {
    final anchorRaw = _preferences.getStringList(KEY_LAST_UPDATE_CHANGE_ANCHOR);
    final anchors = anchorRaw
        ?.map(
          (e) => AddressAnchor.fromJson(jsonDecode(e) as Map<String, dynamic>),
        )
        .toList();
    return addresses
        .map(
          (address) =>
              anchors?.firstWhereOrNull((e) => e.address == address) ??
              defaultAnchorBuilder?.call(address),
        )
        .nonNulls
        .toList();
  }

  @override
  Future<void> setLastUpdateChangeAnchor({
    required List<AddressAnchor> addressAnchors,
  }) =>
      _preferences.setStringList(
        KEY_LAST_UPDATE_CHANGE_ANCHOR,
        addressAnchors.map((e) => jsonEncode(e.toJson())).toList(),
      );

  @override
  String? getDismissedFirmwareUpdateVersion() =>
      _preferences.getString(KEY_DISMISSED_FIRMWARE_UPDATE_VERSION);

  @override
  Future<void> setDismissedFirmwareUpdateVersion(String? version) async {
    if (version == null) {
      await _preferences.remove(KEY_DISMISSED_FIRMWARE_UPDATE_VERSION);
      return;
    }
    await _preferences.setString(
        KEY_DISMISSED_FIRMWARE_UPDATE_VERSION, version);
  }

  @override
  Future<void> setAddressIndexingInfo(List<AddressIndexingInfo> infos) async {
    await _preferences.setStringList(
      KEY_ADDRESS_INDEXING_INFO,
      infos.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  @override
  List<AddressIndexingInfo> getAddressIndexingInfo() {
    final raw = _preferences.getStringList(KEY_ADDRESS_INDEXING_INFO);
    if (raw == null) {
      return [];
    }
    return raw
        .map(
          (e) => AddressIndexingInfo.fromJson(
            jsonDecode(e) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<void> clearAddressIndexingInfo() async {
    await _preferences.remove(KEY_ADDRESS_INDEXING_INFO);
  }
}

enum ConflictAction {
  abort,
  replace,
}
