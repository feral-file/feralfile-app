//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/release_note.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/onboarding/debug_overlay.dart';
import 'package:autonomy_flutter/screen/autonomy_security_page.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/customer_support/support_customer_page.dart';
import 'package:autonomy_flutter/screen/customer_support/support_list_page.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/touchpad_page.dart';
import 'package:autonomy_flutter/screen/detail/preview_primer.dart';
import 'package:autonomy_flutter/screen/detail/royalty/royalty_bloc.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/screen/device_setting/connect_ff1_page.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/now_displaying_page.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/screen/device_setting/start_setup_device_page.dart';
import 'package:autonomy_flutter/screen/github_doc.dart';
import 'package:autonomy_flutter/screen/home/home_bloc.dart';
import 'package:autonomy_flutter/screen/local_feed_server/add_local_feed_server.dart';
import 'package:autonomy_flutter/screen/local_feed_server/custom_feed_servers_page.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/view/record_controller.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/home/view/home_mobile_controller.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/all_channels_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/all_playlists_page.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/name_view_only_page.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_bloc.dart';
import 'package:autonomy_flutter/screen/onboarding_page.dart';
import 'package:autonomy_flutter/onboarding/introduce_page.dart';
import 'package:autonomy_flutter/onboarding/add_address_page.dart';
import 'package:autonomy_flutter/onboarding/setup_ff1_page.dart';
import 'package:autonomy_flutter/onboarding/start_setup_ff1_page.dart';
import 'package:autonomy_flutter/onboarding/add_address_input_page.dart';
import 'package:autonomy_flutter/screen/release_note_detail_page.dart';
import 'package:autonomy_flutter/screen/release_notes_page.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/screen/settings/data_management/data_management_page.dart';
import 'package:autonomy_flutter/screen/settings/data_management/recovery_phrase/recovery_phrase_page.dart';
import 'package:autonomy_flutter/screen/settings/hidden_artworks/hidden_artworks_bloc.dart';
import 'package:autonomy_flutter/screen/settings/hidden_artworks/hidden_artworks_page.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_bloc.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_page.dart';
import 'package:autonomy_flutter/screen/settings/settings_page.dart';
import 'package:autonomy_flutter/screen/wallet/wallet_page.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/transparent_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:page_transition/page_transition.dart';

bool shouldShowOverlay = kDebugMode && Platform.isIOS;

class AppRouter {
  static const previewPrimerPage = 'preview_primer_page';
  static const onboardingPage = 'onboarding_page';
  static const onboardingIntroducePage = 'onboarding_introduce_page';
  static const onboardingAddAddressPage = 'onboarding_add_address_page';
  static const onboardingAddAddressInputPage =
      'onboarding_add_address_input_page';
  static const onboardingSetupFf1Page = 'onboarding_setup_ff1_page';
  static const onboardingStartSetupFf1Page = 'onboarding_start_setup_ff1_page';
  static const nameLinkedAccountPage = 'name_linked_account_page';
  static const homePage = 'home_page';
  static const recordControllerPage = 'record_controller_page';
  static const artworkDetailsPage = 'artwork_details_page';
  static const settingsPage = 'settings_page';
  static const scanQRPage = 'scan_qr_page';
  static const recoveryPhrasePage = 'recovery_phrase_page';
  static const autonomySecurityPage = 'security_page';
  static const releaseNotesPage = 'release_notes_page';
  static const releaseNoteDetailPage = 'release_note_detail_page';
  static const hiddenArtworksPage = 'hidden_artworks_page';
  static const supportCustomerPage = 'support_customer_page';
  static const supportListPage = 'support_list_page';
  static const supportThreadPage = 'support_thread_page';
  static const githubDocPage = 'github_doc_page';
  static const preferencesPage = 'preferences_page';
  static const walletPage = 'wallet_page';
  static const dataManagementPage = 'data_management_page';
  static const keyboardControlPage = 'keyboard_control_page';
  static const touchPadPage = 'touch_pad_page';
  static const viewExistingAddressPage = 'view_existing_address_page';
  static const accessMethodPage = 'access_method_page';
  static const collectionPage = 'collection_page';
  static const bluetoothDevicePortalPage = 'bluetooth_device_portal_page';
  static const scanWifiNetworkPage = 'scan_wifi_network_page';
  static const sendWifiCredentialPage = 'send_wifi_credential_page';
  static const nowDisplayingPage = 'now_displaying_page';
  static const bluetoothConnectedDeviceConfig =
      'bluetooth_connected_device_config';
  static const handleBluetoothDeviceScanDeeplinkScreen =
      'handle_bluetooth_device_scan_deeplink_screen';
  static const channelDetailPage = 'channel_detail_page';
  static const dp1PlaylistDetailsPage = 'do1_playlist_details_page';
  static const voiceCommandPage = 'voice_command_page';
  static const addLocalFeedServerPage = 'add_local_feed_server_page';
  static const customFeedServersPage = 'custom_feed_servers_page';
  static const allPlaylistsPage = 'all_playlists_page';
  static const allChannelsPage = 'all_channels_page';
  static const connectFF1 = 'connect_ff1';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    log.info('[onGenerateRoute] Route: ${settings.name}');
    final accountsBloc = injector<AccountsBloc>();

    final identityBloc = injector<IdentityBloc>();
    final canvasDeviceBloc = injector<CanvasDeviceBloc>();

    final subscriptionBloc = injector<SubscriptionBloc>();

    final royaltyBloc = RoyaltyBloc(injector());

    switch (settings.name) {
      case onboardingPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const OnboardingPage(),
        );

      case onboardingIntroducePage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => IntroducePage(),
        );

      case onboardingAddAddressPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => DebugOverlay(
            imagePath: 'assets/images/screenshots/onboarding_2.png',
            child: const OnboardingAddAddressPage(),
          ),
        );

      case onboardingAddAddressInputPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const OnboardingAddAddressInputPage(),
        );

      case onboardingSetupFf1Page:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => DebugOverlay(
            imagePath: 'assets/images/screenshots/onboarding_3.png',
            child: const OnboardingSetupFf1Page(),
          ),
        );

      case onboardingStartSetupFf1Page:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const StartSetupFf1Page(),
        );

      case previewPrimerPage:
        return PageTransition(
          type: PageTransitionType.fade,
          curve: Curves.easeIn,
          duration: const Duration(milliseconds: 250),
          settings: settings,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: identityBloc),
            ],
            child: PreviewPrimerPage(
              token: settings.arguments! as AssetToken,
            ),
          ),
        );

      case homePage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => HomeBloc(),
              ),
              BlocProvider.value(value: canvasDeviceBloc),
              BlocProvider.value(value: subscriptionBloc),
            ],
            child: const MobileControllerHomePage(),
          ),
        );

      case AppRouter.recoveryPhrasePage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const RecoveryPhrasePage(),
        );

      case AppRouter.nameLinkedAccountPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => NameViewOnlyAddressPage(
            address: settings.arguments! as WalletAddress,
          ),
        );

      case scanQRPage:
        final payload = settings.arguments! as ScanQRPagePayload;
        return PageTransition(
          settings: settings,
          type: PageTransitionType.topToBottom,
          curve: Curves.easeIn,
          child: ScanQRPage(
            payload: payload,
          ),
        );

      case settingsPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: accountsBloc),
              BlocProvider.value(value: subscriptionBloc),
              BlocProvider.value(value: identityBloc),
            ],
            child: const SettingsPage(),
          ),
        );

      case viewExistingAddressPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => BlocProvider(
            create: (_) => ViewExistingAddressBloc(injector(), injector()),
            child: ViewExistingAddress(
              payload: settings.arguments! as ViewExistingAddressPayload,
            ),
          ),
        );

      case artworkDetailsPage:
        return PageTransition(
          type: PageTransitionType.fade,
          curve: Curves.easeIn,
          duration: const Duration(milliseconds: 250),
          settings: settings,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: accountsBloc),
              BlocProvider.value(value: identityBloc),
              BlocProvider(create: (_) => royaltyBloc),
              BlocProvider(
                create: (_) => ArtworkDetailBloc(),
              ),
              BlocProvider.value(
                value: canvasDeviceBloc,
              ),
              BlocProvider.value(
                value: subscriptionBloc,
              ),
            ],
            child: ArtworkDetailPage(
              payload: settings.arguments! as ArtworkDetailPayload,
            ),
          ),
        );

      case autonomySecurityPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const AutonomySecurityPage(),
        );

      case releaseNotesPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const ReleaseNotesPage(),
        );

      case releaseNoteDetailPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => ReleaseNoteDetailPage(
            releaseNote: settings.arguments! as ReleaseNote,
          ),
        );

      case supportCustomerPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const SupportCustomerPage(),
        );

      case supportListPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const SupportListPage(),
        );

      case supportThreadPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => SupportThreadPage(
            payload: settings.arguments! as SupportThreadPayload,
          ),
        );
      case hiddenArtworksPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => HiddenArtworksBloc(
                  injector<AppDataManager>(),
                  injector(),
                ),
              ),
            ],
            child: const HiddenArtworksPage(),
          ),
        );

      case githubDocPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => GithubDocPage(
            payload: settings.arguments! as GithubDocPayload,
          ),
        );

      case walletPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: accountsBloc),
            ],
            child: WalletPage(
              payload: settings.arguments as WalletPagePayload?,
            ),
          ),
        );
      case preferencesPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => PreferencesBloc(injector()),
              ),
              BlocProvider.value(value: accountsBloc),
            ],
            child: const PreferencePage(),
          ),
        );

      case dataManagementPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: identityBloc),
            ],
            child: const DataManagementPage(),
          ),
        );

      case keyboardControlPage:
        return TransparentRoute(
          settings: settings,
          builder: (context) {
            final payload = settings.arguments! as KeyboardControlPagePayload;
            return KeyboardControlPage(
              payload: payload,
            );
          },
        );
      case touchPadPage:
        return TransparentRoute(
          settings: settings,
          builder: (context) {
            final payload = settings.arguments! as TouchPadPagePayload;
            return TouchPadPage(
              payload: payload,
            );
          },
        );

      case bluetoothDevicePortalPage:
        final payload = settings.arguments! as BluetoothDevicePortalPagePayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => BluetoothDevicePortalPage(payload: payload),
        );

      case scanWifiNetworkPage:
        final payload = settings.arguments! as ScanWifiNetworkPagePayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => ScanWifiNetworkPage(payload: payload),
        );

      case sendWifiCredentialPage:
        final payload = settings.arguments! as SendWifiCredentialsPagePayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => SendWifiCredentialsPage(
            payload: payload,
          ),
        );

      case nowDisplayingPage:
        return PageTransition(
          type: PageTransitionType.fade,
          curve: Curves.easeIn,
          duration: const Duration(milliseconds: 500),
          settings: settings,
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => ArtworkDetailBloc(),
              ),
              BlocProvider.value(value: accountsBloc),
              BlocProvider.value(value: identityBloc),
              BlocProvider(create: (_) => royaltyBloc),
            ],
            child: const NowDisplayingPage(),
          ),
        );

      case bluetoothConnectedDeviceConfig:
        final payload =
            settings.arguments! as BluetoothConnectedDeviceConfigPayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => BluetoothConnectedDeviceConfig(
            payload: payload,
          ),
        );

      case handleBluetoothDeviceScanDeeplinkScreen:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => HandleBluetoothDeviceScanDeeplinkScreen(
            payload: settings.arguments!
                as HandleBluetoothDeviceScanDeeplinkScreenPayload,
          ),
        );

      case channelDetailPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: subscriptionBloc),
            ],
            child: ChannelDetailPage(
              payload: settings.arguments! as ChannelDetailPagePayload,
            ),
          ),
        );

      case dp1PlaylistDetailsPage:
        final payload = settings.arguments! as DP1PlaylistDetailsScreenPayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: subscriptionBloc),
              BlocProvider.value(value: canvasDeviceBloc),
            ],
            child: DP1PlaylistDetailsScreen(
              payload: payload,
            ),
          ),
        );

      case voiceCommandPage:
        final payload = settings.arguments as RecordControllerScreenPayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(
                value: injector<RecordBloc>(),
              ),
              BlocProvider.value(
                value: injector<MeiliSearchBloc>(),
              ),
            ],
            child: RecordControllerScreen(
              payload: payload,
            ),
          ),
        );

      case addLocalFeedServerPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const AddLocalFeedServerPage(),
        );

      case customFeedServersPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const CustomFeedServersPage(),
        );

      case allPlaylistsPage:
        final payload = settings.arguments! as AllPlaylistsPagePayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => Stack(
            children: [
              AllPlaylistsPage(payload: payload),
              if (shouldShowOverlay)
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 0.3,
                    child: Image.asset(
                      "assets/images/Curated Playlist.png",
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
            ],
          ),
        );

      case allChannelsPage:
        final payload = settings.arguments! as AllChannelsPagePayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => BlocProvider<ChannelsBloc>.value(
            value: injector<ChannelsBloc>(
              instanceName: ChannelsBlocInstance.curated.instanceName,
            ),
            child: AllChannelsPage(payload: payload),
          ),
        );

      case connectFF1:
        final payload = settings.arguments! as ConnectFF1PagePayload;
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => ConnectFF1Page(payload: payload),
        );

      default:
        throw Exception('Invalid route: ${settings.name}');
    }
  }
}
