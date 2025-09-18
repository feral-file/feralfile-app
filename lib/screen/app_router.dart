//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/screen/account/test_artwork_screen.dart';
import 'package:autonomy_flutter/screen/activation/playlist_activation/playlist_activation_page.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_details_bloc.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_details_page.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_exhibitions_page.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_posts_page.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_works_page.dart';
import 'package:autonomy_flutter/screen/autonomy_security_page.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bug_bounty_page.dart';
import 'package:autonomy_flutter/screen/collection_pro/artists_list_page/artists_list_page.dart';
import 'package:autonomy_flutter/screen/customer_support/support_customer_page.dart';
import 'package:autonomy_flutter/screen/customer_support/support_list_page.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_page.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/keyboard_control_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/touchpad_page.dart';
import 'package:autonomy_flutter/screen/detail/preview_primer.dart';
import 'package:autonomy_flutter/screen/detail/royalty/royalty_bloc.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/now_displaying_page.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/screen/device_setting/start_setup_device_page.dart';
import 'package:autonomy_flutter/screen/exhibition_custom_note/exhibition_custom_note_page.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_bloc.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/screen/feralfile_artwork_preview/feralfile_artwork_preview_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_artwork_preview/feralfile_artwork_preview_page.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_series/feralfile_series_page.dart';
import 'package:autonomy_flutter/screen/github_doc.dart';
import 'package:autonomy_flutter/screen/home/collection_home_page.dart';
import 'package:autonomy_flutter/screen/home/home_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_navigation_page.dart';
import 'package:autonomy_flutter/screen/home/list_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/home/organize_home_page.dart';
import 'package:autonomy_flutter/screen/indexer_collection/indexer_collection_bloc.dart';
import 'package:autonomy_flutter/screen/indexer_collection/indexer_collection_page.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/view/record_controller.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/home/view/home_mobile_controller.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/name_view_only_page.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_bloc.dart';
import 'package:autonomy_flutter/screen/onboarding_page.dart';
import 'package:autonomy_flutter/screen/playlists/add_new_playlist/add_new_playlist.dart';
import 'package:autonomy_flutter/screen/playlists/add_to_playlist/add_to_playlist.dart';
import 'package:autonomy_flutter/screen/playlists/edit_playlist/edit_playlist.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_screen.dart';
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
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/transparent_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:page_transition/page_transition.dart';

GlobalKey<HomeNavigationPageState> homePageKey = GlobalKey();
GlobalKey<HomeNavigationPageState> homePageNoTransactionKey = GlobalKey();
GlobalKey<FeralfileHomePageState> feralFileHomeKey = GlobalKey();
final GlobalKey<DailyWorkPageState> dailyWorkKey = GlobalKey();

class AppRouter {
  static const createPlayListPage = 'create_playlist_page';
  static const viewPlayListPage = 'view_playlist_page';
  static const editPlayListPage = 'edit_playlist_page';
  static const previewPrimerPage = 'preview_primer_page';
  static const onboardingPage = 'onboarding_page';
  static const newOnboardingPage = 'new_onboarding_page';
  static const nameLinkedAccountPage = 'name_linked_account_page';
  static const homePage = 'home_page';
  static const oldHomePage = 'old_home_page';
  static const recordControllerPage = 'record_controller_page';
  static const enterCommandPage = 'enter_command_page';
  static const artworkDetailsPage = 'artwork_details_page';
  static const galleryPage = 'gallery_page';
  static const settingsPage = 'settings_page';
  static const connectionDetailsPage = 'connection_details_page';
  static const linkedWalletDetailsPage = 'linked_wallet_details_page';
  static const scanQRPage = 'scan_qr_page';
  static const globalReceivePage = 'global_receive_page';
  static const recoveryPhrasePage = 'recovery_phrase_page';
  static const testArtwork = 'test_artwork';
  static const autonomySecurityPage = 'security_page';
  static const releaseNotesPage = 'release_notes_page';
  static const hiddenArtworksPage = 'hidden_artworks_page';
  static const supportCustomerPage = 'support_customer_page';
  static const supportListPage = 'support_list_page';
  static const supportThreadPage = 'support_thread_page';
  static const bugBountyPage = 'bug_bounty_page';
  static const githubDocPage = 'github_doc_page';
  static const preferencesPage = 'preferences_page';
  static const walletPage = 'wallet_page';
  static const dataManagementPage = 'data_management_page';
  static const keyboardControlPage = 'keyboard_control_page';
  static const touchPadPage = 'touch_pad_page';
  static const predefinedCollectionPage = 'predefined_collection_page';
  static const addToCollectionPage = 'add_to_collection_page';
  static const exhibitionDetailPage = 'exhibition_detail_page';
  static const ffArtworkPreviewPage = 'ff_artwork_preview_page';
  static const feralFileSeriesPage = 'feral_file_series_page';
  static const indexerCollectionPage = 'indexer_collection_page';
  static const viewExistingAddressPage = 'view_existing_address_page';
  static const selectAddressesPage = 'select_addresses_page';
  static const addressAliasPage = 'address_alias_page';
  static const accessMethodPage = 'access_method_page';
  static const collectionPage = 'collection_page';
  static const organizePage = 'organize_page';
  static const exhibitionsPage = 'exhibitions_page';
  static const explorePage = 'explore_page';
  static const artistsListPage = 'artists_list_page';
  static const exhibitionCustomNote = 'exhibition_custom_note';
  static const dailyWorkPage = 'daily_work_page';
  static const alumniDetailsPage = 'alumni_details_page';
  static const alumniWorksPage = 'alumni_works_page';
  static const alumniExhibitionsPage = 'alumni_exhibitions_page';
  static const alumniPostPage = 'alumni_posts_page';
  static const featuredPage = 'featured_page';
  static const artworksPage = 'artworks_page';
  static const artistsPage = 'artists_page';
  static const curatorsPage = 'curators_page';
  static const playlistActivationPage = 'playlist_activation_page';
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

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    log.info('[onGenerateRoute] Route: ${settings.name}');
    final accountsBloc = injector<AccountsBloc>();

    final identityBloc = injector<IdentityBloc>();
    final canvasDeviceBloc = injector<CanvasDeviceBloc>();

    final subscriptionBloc = injector<SubscriptionBloc>();
    final listPlaylistBloc = injector<ListPlaylistBloc>();

    final royaltyBloc = RoyaltyBloc(injector());

    switch (settings.name) {
      case artistsListPage:
        return PageTransition(
          type: PageTransitionType.fade,
          curve: Curves.easeIn,
          duration: const Duration(milliseconds: 250),
          settings: settings,
          child: ArtistsListPage(
            payload: settings.arguments! as ArtistsListPagePayload,
          ),
        );

      case viewPlayListPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: canvasDeviceBloc),
              BlocProvider.value(value: subscriptionBloc),
            ],
            child: ViewPlaylistScreen(
              payload: settings.arguments! as ViewPlaylistScreenPayload,
            ),
          ),
        );
      case createPlayListPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => AddNewPlaylistScreen(
            playListModel: settings.arguments as PlayListModel?,
          ),
        );
      case editPlayListPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => EditPlaylistScreen(
            playListModel: settings.arguments as PlayListModel?,
          ),
        );
      case onboardingPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const OnboardingPage(),
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
      case oldHomePage:
        final payload = settings.arguments as HomeNavigationPagePayload?;
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation1, animation2) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => HomeBloc(),
              ),
              BlocProvider.value(value: identityBloc),
              BlocProvider.value(value: royaltyBloc),
              BlocProvider.value(
                value: subscriptionBloc,
              ),
              BlocProvider.value(value: canvasDeviceBloc),
              BlocProvider.value(value: listPlaylistBloc),
            ],
            child: HomeNavigationPage(
              key: homePageNoTransactionKey,
              payload: HomeNavigationPagePayload(
                fromOnboarding: true,
                startedTab: payload?.startedTab,
              ),
            ),
          ),
          transitionDuration: Duration.zero,
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

      case AppRouter.testArtwork:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const TestArtworkScreen(),
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
                create: (_) => ArtworkDetailBloc(
                  injector(),
                  injector(),
                  injector(),
                  injector(),
                  injector(),
                  injector(),
                ),
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
        return PageTransition(
          settings: settings,
          type: PageTransitionType.bottomToTop,
          curve: Curves.easeIn,
          child: ReleaseNotesPage(
            releaseNotes: settings.arguments! as String,
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

      case bugBountyPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => const BugBountyPage(),
        );

      case hiddenArtworksPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => HiddenArtworksBloc(
                  injector<ConfigurationService>(),
                  injector(),
                ),
              ),
            ],
            child: const HiddenArtworksPage(),
          ),
        );

      case exhibitionDetailPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => ExhibitionDetailBloc(injector()),
              ),
              BlocProvider.value(
                value: canvasDeviceBloc,
              ),
              BlocProvider.value(
                value: subscriptionBloc,
              ),
              BlocProvider(create: (_) => FFArtworkPreviewBloc()),
            ],
            child: ExhibitionDetailPage(
              payload: settings.arguments! as ExhibitionDetailPayload,
            ),
          ),
        );
      case ffArtworkPreviewPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(
                value: royaltyBloc,
              ),
              BlocProvider.value(
                value: subscriptionBloc,
              ),
              BlocProvider(create: (_) => FFArtworkPreviewBloc()),
            ],
            child: FeralFileArtworkPreviewPage(
              payload:
                  settings.arguments! as FeralFileArtworkPreviewPagePayload,
            ),
          ),
        );

      case feralFileSeriesPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => FeralFileSeriesBloc(injector()),
              ),
            ],
            child: FeralFileSeriesPage(
              payload: settings.arguments! as FeralFileSeriesPagePayload,
            ),
          ),
        );

      case indexerCollectionPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => IndexerCollectionBloc(injector()),
              ),
            ],
            child: IndexerCollectionPage(
              payload: settings.arguments! as IndexerCollectionPagePayload,
            ),
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

      case predefinedCollectionPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) {
            final payload =
                settings.arguments! as PredefinedCollectionScreenPayload;
            return PredefinedCollectionScreen(
              payload: payload,
            );
          },
        );
      case addToCollectionPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => AddToCollectionScreen(
            playList: settings.arguments! as PlayListModel,
          ),
        );

      case exhibitionCustomNote:
        return MaterialPageRoute(
          builder: (context) => ExhibitionCustomNotePage(
            info: settings.arguments! as CustomExhibitionNote,
          ),
        );

      case dailyWorkPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => injector<DailyWorkBloc>(),
              ),
              BlocProvider.value(value: canvasDeviceBloc),
            ],
            child: const DailyWorkPage(),
          ),
        );

      case alumniDetailsPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => AlumniDetailsBloc()),
            ],
            child: AlumniDetailsPage(
              payload: settings.arguments! as AlumniDetailsPagePayload,
            ),
          ),
        );
      case alumniWorksPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => AlumniWorksPage(
            payload: settings.arguments! as AlumniWorksPagePayload,
          ),
        );

      case alumniExhibitionsPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => AlumniExhibitionsPage(
            payload: settings.arguments! as AlumniExhibitionsPagePayload,
          ),
        );

      case alumniPostPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => AlumniPostsPage(
            payload: settings.arguments! as AlumniPostsPagePayload,
          ),
        );
      case collectionPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: subscriptionBloc),
            ],
            child: const CollectionHomePage(),
          ),
        );
      case organizePage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: subscriptionBloc),
              BlocProvider.value(value: listPlaylistBloc),
            ],
            child: const OrganizeHomePage(),
          ),
        );

      case playlistActivationPage:
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) => PlaylistActivationPage(
            payload: settings.arguments! as PlaylistActivationPagePayload,
          ),
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
                create: (_) => ArtworkDetailBloc(
                  injector(),
                  injector(),
                  injector(),
                  injector(),
                  injector(),
                  injector(),
                ),
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

      default:
        throw Exception('Invalid route: ${settings.name}');
    }
  }
}
