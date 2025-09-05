import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/dailies.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_state.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview_detail/preview_detail_widget.dart';
import 'package:autonomy_flutter/screen/exhibition_details/exhibition_detail_page.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/metric_client_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/user_interactivity_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/metric_helper.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/alumni_widget.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/daily_progress_bar.dart';
import 'package:autonomy_flutter/view/exhibition_item.dart';
import 'package:autonomy_flutter/view/important_note_view.dart';
import 'package:autonomy_flutter/view/keep_alive_widget.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_view.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:url_launcher/url_launcher.dart';

class DailyWorkPage extends StatefulWidget {
  const DailyWorkPage({super.key});

  @override
  State<DailyWorkPage> createState() => DailyWorkPageState();
}

class DailyWorkPageState extends State<DailyWorkPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  Timer? _timer;
  Duration? _remainingDuration;
  Timer? _progressTimer;
  PageController? _pageController;
  late int _currentIndex;
  ScrollController? _scrollController;
  final _artworkKey = GlobalKey<ArtworkPreviewWidgetState>();
  final _displayButtonKey = GlobalKey<FFCastButtonState>();
  late final DailyWorkBloc _dailyWorkBloc;

  DailyToken? get _currentDailyToken => _dailyWorkBloc.state.currentDailyToken;

  bool _trackingDailyLiked = false;
  Timer? _trackingDailyLikedTimer;
  static const _stayDurationLikingThreshold = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _dailyWorkBloc = injector<DailyWorkBloc>();
    _dailyWorkBloc.add(GetDailyAssetTokenEvent());
    _pageController = PageController();
    _pageController!.addListener(_pageControllerListener);
    _currentIndex = _pageController!.initialPage;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressTimer?.cancel();
    _pageController?.dispose();
    _scrollController?.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _pageControllerListener() {
    if (_pageController!.page != 0) {
      pauseDailyWork();
    } else {
      resumeDailyWork();
    }
  }

  void openDisplayDialog() {
    // ignore isSubscribed because it's not necessary
    unawaited(_displayButtonKey.currentState?.onTap(context, true));
  }

  void didPushed() {
    _stopTrackingLiked();
  }

  void didTapDaily() {
    trackInterest();
  }

  void trackInterest() {
    if (_trackingDailyLiked) {
      return;
    }
    log.info('start trackingInterest in Daily');
    _trackingDailyLiked = true;
    _trackingDailyLikedTimer =
        Timer(_stayDurationLikingThreshold, _setUserLiked);
  }

  void _stopTrackingLiked() {
    log.info('stopTrackingInterest in Daily');
    _trackingDailyLiked = false;
    _trackingDailyLikedTimer?.cancel();
  }

  void _setUserLiked() {
    if (!_trackingDailyLiked) {
      return;
    }
    log.info('Set User Interested in Daily');
    _stopTrackingLiked();
    if (_currentDailyToken == null) {
      return;
    }
    unawaited(
      injector<UserInteractivityService>().likeDailyWork(_currentDailyToken!),
    );
  }

  Future<void> scheduleNextDailyWork(BuildContext context) async {
    setState(() {
      _remainingDuration = _calcRemainingDuration;
    });
    const defaultDuration = Duration(hours: 1);
    final nextDailyDuration = _calcRemainingDuration;
    final duration = nextDailyDuration > defaultDuration
        ? defaultDuration
        : nextDailyDuration;
    _timer?.cancel();
    _timer = Timer(duration, () {
      log.info('Get Daily Asset Token');
      _dailyWorkBloc.add(GetDailyAssetTokenEvent());
    });
  }

  DateTime get _nextDailyDateTime {
    const defaultScheduleTime = 6;
    final configScheduleTime =
        injector<RemoteConfigService>().getConfig<String>(
      ConfigGroup.daily,
      ConfigKey.scheduleTime,
      defaultScheduleTime.toString(),
    );
    final now =
        DateTime.now().subtract(Duration(hours: int.parse(configScheduleTime)));
    final startNextDay = DateTime(now.year, now.month, now.day + 1).add(
      Duration(hours: int.parse(configScheduleTime), seconds: 3),
      // add 3 seconds to avoid the same artwork
    );
    return startNextDay;
  }

  void pauseDailyWork() {
    _artworkKey.currentState?.pause();
    muteDailyWork();
  }

  void resumeDailyWork() {
    if (_pageController?.page == 0) {
      _artworkKey.currentState?.resume();
      unmuteDailyWork();
    }
  }

  void muteDailyWork() {
    _artworkKey.currentState?.mute();
  }

  void unmuteDailyWork() {
    _artworkKey.currentState?.unmute();
  }

  void scrollToTop() {
    unawaited(
      _pageController?.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Duration? get _calcTotalDuration => const Duration(hours: 24);

  Duration get _calcRemainingDuration =>
      _nextDailyDateTime.difference(DateTime.now());

  void updateProgressStatus() {
    _progressTimer?.cancel();
    // Update After Each 5 Minutes
    final remainingDuration = _calcRemainingDuration;
    final timerDuration = remainingDuration.inHours >= 1
        ? const Duration(minutes: 5)
        : remainingDuration.inMinutes >= 1
            ? const Duration(minutes: 1)
            : const Duration(seconds: 3);
    _progressTimer = Timer(timerDuration, () {
      setState(() {
        _remainingDuration = _calcRemainingDuration;
      });
      updateProgressStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: AppColor.primaryBlack,
      appBar: getDarkEmptyAppBar(Colors.transparent),
      body: _buildBody(),
    );
  }

  Widget _buildBody() => BlocConsumer<DailyWorkBloc, DailiesWorkState>(
        bloc: _dailyWorkBloc,
        builder: (context, state) => PageView(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          children: [
            KeepAliveWidget(child: _dailyPreview()),
            KeepAliveWidget(child: _dailyDetails(context)),
          ],
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        listener: (BuildContext context, DailiesWorkState state) {},
        listenWhen: (previous, current) {
          if (current.assetTokens.firstOrNull?.id !=
              previous.assetTokens.firstOrNull?.id) {
            if (current.assetTokens.isNotEmpty) {
              // send metric event
              unawaited(
                injector<MetricClientService>().addEvent(
                  MetricEventName.dailyView,
                  data: {
                    MetricParameter.tokenId: current.assetTokens.first.id,
                  },
                ),
              );
              trackInterest();
            }
          }
          return true;
        },
      );

  Widget _header(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              'daily_work'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .ppMori700Black36
                  .copyWith(color: AppColor.white),
              textAlign: TextAlign.left,
            ),
          ),
          FFCastButton(
            key: _displayButtonKey,
            displayKey: CastDailyWorkRequest.displayKey,
            onDeviceSelected: (device) {
              context.read<CanvasDeviceBloc>().add(
                    CanvasDeviceCastDailyWorkEvent(
                      device,
                      CastDailyWorkRequest(),
                    ),
                  );
            },
            onTap: _setUserLiked,
            text: 'display'.tr(),
            shouldCheckSubscription: false,
          ),
          const SizedBox(width: 16),
          // close button
          GestureDetector(
            onTap: () {
              injector<NavigationService>().goBack();
            },
            child: SvgPicture.asset(
              'assets/images/iconClose.svg',
              width: 34,
              height: 34,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          )
        ],
      );

  Widget _progressBar(
    BuildContext context,
    Duration remainingDuration,
    Duration totalDuration,
  ) {
    return DailyProgressBar(
      remainingDuration: remainingDuration,
      totalDuration: totalDuration,
    );
  }

  Widget _artworkInfoIcon() => Semantics(
        label: 'artworkInfoIcon',
        child: GestureDetector(
          onTap: () {
            _currentIndex == 0
                ? unawaited(
                    _pageController?.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  )
                : unawaited(
                    _pageController?.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  );
          },
          child: Container(
            padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8),
            child: SvgPicture.asset(
              _currentIndex == 0
                  ? 'assets/images/info_white.svg'
                  : 'assets/images/info_white_active.svg',
              width: 22,
              height: 22,
            ),
          ),
        ),
      );

  Widget _dailyPreview() => Column(
        children: [
          SizedBox(
            height: MediaQuery.paddingOf(context).top,
          ),
          // const NowDisplaying(),
          const SizedBox(
            height: 32,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _header(context),
          ),
          Expanded(
            child: BlocConsumer<DailyWorkBloc, DailiesWorkState>(
              bloc: _dailyWorkBloc,
              listener: (context, state) {
                if (state.assetTokens.isNotEmpty) {
                  // get identity
                  final identitiesList = <String>[];
                  final assetToken = state.assetTokens.first;
                  identitiesList
                    ..add(assetToken.artistName!)
                    ..add(assetToken.owner);
                  context
                      .read<IdentityBloc>()
                      .add(GetIdentityEvent(identitiesList));
                  unawaited(scheduleNextDailyWork(context));
                  updateProgressStatus();
                }
              },
              builder: (context, state) {
                final assetToken = state.assetTokens.firstOrNull;
                final artwork = state.currentDailyToken?.artwork;
                if (assetToken == null) {
                  return const LoadingWidget();
                }
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: IgnorePointer(
                          child: ArtworkPreviewWidget(
                            key: _artworkKey,
                            useIndexer: true,
                            identity: ArtworkIdentity(
                              assetToken.id,
                              assetToken.owner,
                            ),
                            shouldUpdateStatusWhenDidPopNext: false,
                          ),
                        ),
                      ),
                    ),
                    if (_remainingDuration != null &&
                        _calcTotalDuration != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _progressBar(
                          context,
                          _remainingDuration!,
                          _calcTotalDuration!,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: _tokenInfo(context, assetToken, artwork),
                    ),
                  ],
                );
              },
            ),
          ),
          MultiValueListenableBuilder(
            valueListenables: [nowDisplayingShowing],
            builder: (context, values, _) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: values.every((value) => value as bool)
                    ? 100 + kNowDisplayingHeight - 16
                    : 100,
              );
            },
          ),
        ],
      );

  Widget _tokenInfo(
    BuildContext context,
    AssetToken assetToken,
    Artwork? artwork,
  ) {
    final identityState = context.watch<IdentityBloc>().state;
    final artistName =
        assetToken.artistName?.toIdentityOrMask(identityState.identityMap) ??
            assetToken.artistID ??
            '';
    final title = assetToken.displayTitle ?? '';
    final titleWithEditionName =
        (artwork?.series?.settings?.artworkModel == ArtworkModel.multiUnique)
            ? '$title ${assetToken.editionName}'
            : title;
    return Row(
      children: [
        Expanded(
          child: ArtworkDetailsHeader(
            title: titleWithEditionName,
            subTitle: artistName,
            onSubTitleTap: assetToken.artistID != null && assetToken.isFeralfile
                ? () => unawaited(
                      injector<NavigationService>()
                          .openFeralFileArtistPage(assetToken.artistID!),
                    )
                : null,
          ),
        ),
        _artworkInfoIcon(),
      ],
    );
  }

  Widget _dailyDetails(
    BuildContext context,
  ) {
    return BlocBuilder<DailyWorkBloc, DailiesWorkState>(
      bloc: _dailyWorkBloc,
      builder: (context, state) {
        final assetToken = state.assetTokens.firstOrNull;
        if (assetToken == null) {
          return loadingIndicator();
        }
        return DailyDetails(
          state: state,
          pageController: _pageController,
          setUserLiked: _setUserLiked,
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

Widget exhibitionInfo(BuildContext context, Exhibition exhibition) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'exhibited_in'.tr(),
        style: theme.textTheme.ppMori400Grey12,
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () {
          unawaited(
            Navigator.of(context).pushNamed(
              AppRouter.exhibitionDetailPage,
              arguments: ExhibitionDetailPayload(
                exhibitions: [exhibition],
                index: 0,
              ),
            ),
          );
        },
        child: ExhibitionCard(
          exhibition: exhibition,
          viewableExhibitions: [exhibition],
          horizontalMargin: 16,
        ),
      ),
      const SizedBox(height: 48),
      if (exhibition.noteBrief?.isNotEmpty == true) ...[
        HtmlWidget(
          exhibition.noteBrief!,
          customStylesBuilder: auHtmlStyle,
          textStyle: theme.textTheme.ppMori400White14,
          onTapUrl: (url) async {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            return true;
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            await injector<NavigationService>()
                .openFeralFileExhibitionNotePage(exhibition.slug);
          },
          child: Text(
            'read_more'.tr(),
            style: theme.textTheme.ppMori400White14.copyWith(
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ],
  );
}

Widget shortArtistProfile(BuildContext context, AlumniAccount artist) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'artist_profile'.tr(),
          style: Theme.of(context).textTheme.ppMori400Grey12,
        ),
        const SizedBox(height: 32),
        AlumniProfile(
          alumni: artist,
          isShowAlumniRole: false,
        ),
        const SizedBox(height: 32),
        Text(
          'read_more'.tr(),
          style: Theme.of(context).textTheme.ppMori400White14.copyWith(
                decoration: TextDecoration.underline,
              ),
        ),
      ],
    );

class DailyDetails extends StatelessWidget {
  DailyDetails({
    required this.state,
    super.key,
    this.pageController,
    this.setUserLiked,
  });

  final DailiesWorkState state;
  final PageController? pageController;
  final Function? setUserLiked;

  // DailyWorkBloc get _dailyWorkBloc => injector<DailyWorkBloc>();

  final _scrollController = ScrollController();

  static const _scrollLikingThreshold = 100.0;

  @override
  Widget build(BuildContext context) {
    return _dailyDetails(context);
  }

  Widget _dailyDetails(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final assetToken = state.assetTokens.firstOrNull;
    if (assetToken == null) {
      return loadingIndicator();
    }
    final identityState = context.watch<IdentityBloc>().state;
    final artistName =
        assetToken.artistName?.toIdentityOrMask(identityState.identityMap) ??
            assetToken.artistID ??
            '';
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction == ScrollDirection.forward &&
            _scrollController.offset < 10) {
          unawaited(
            pageController?.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          );
        }
        if (_scrollController.offset > _scrollLikingThreshold) {
          setUserLiked?.call();
        }
        return true;
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.top + 48,
            ),
          ),
          if (state.currentDailyToken != null &&
              state.currentExhibition != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _mediumDescription(
                  context,
                  state.currentDailyToken!,
                  state.currentExhibition!,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
          // artwork desc
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HtmlWidget(
                customStylesBuilder: auHtmlStyle,
                assetToken.description ?? '',
                textStyle: theme.textTheme.ppMori400White12,
                onTapUrl: (url) async {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                  return true;
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 64),
          ),

          // Daily note if not empty
          if (state.currentDailyToken?.dailyNote?.isNotEmpty ?? false) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ImportantNoteView(
                  title: 'daily_note'.tr(),
                  titleStyle: theme.textTheme.ppMori400White12,
                  note: state.currentDailyToken!.dailyNote!,
                  noteStyle: theme.textTheme.ppMori400White12,
                  backgroundColor: AppColor.auGreyBackground,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 64),
            ),
          ],

          // Artist Profile
          if (state.currentArtist != null) ...[
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () {
                  unawaited(
                    injector<NavigationService>()
                        .openFeralFileArtistPage(state.currentArtist!.id),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: shortArtistProfile(context, state.currentArtist!),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: addDivider(
                height: 40,
                color: AppColor.auQuickSilver,
                thickness: 0.5,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
          if (state.currentExhibition != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: exhibitionInfo(context, state.currentExhibition!),
              ),
            ),
            SliverToBoxAdapter(
              child: addDivider(
                height: 40,
                color: AppColor.auQuickSilver,
                thickness: 0.5,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: artworkDetailsMetadataSection(
                context,
                assetToken,
                artistName,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: artworkDetailsRightSection(
                context,
                assetToken,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 100),
              child: SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediumDescription(
    BuildContext context,
    DailyToken currentDailyToken,
    Exhibition exhibition,
  ) {
    final theme = Theme.of(context);
    final seriesId = currentDailyToken.artwork?.seriesID;
    if (seriesId == null) {
      return const SizedBox();
    }

    final mediumDesc = List<String>.from(
      exhibition.series
              ?.firstWhereOrNull((series) => series.id == seriesId)
              ?.metadata?['mediumDescription'] as List? ??
          [],
    );

    if (mediumDesc.isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mediumDesc
          .map(
            (desc) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                desc,
                style: theme.textTheme.ppMori400White14,
              ),
            ),
          )
          .toList(),
    );
  }
}
