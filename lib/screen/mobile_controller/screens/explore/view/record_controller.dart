import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/record_processing_status_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/hight_light_tetx_controller.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/llm_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class RecordControllerScreenPayload {
  RecordControllerScreenPayload({
    this.isListening = true,
  });
  final bool isListening;
}

class RecordControllerScreen extends StatefulWidget {
  const RecordControllerScreen({super.key, required this.payload});
  final RecordControllerScreenPayload payload;

  @override
  State<RecordControllerScreen> createState() => _RecordControllerScreenState();
}

class _RecordControllerScreenState extends State<RecordControllerScreen>
    with
        AutomaticKeepAliveClientMixin,
        RouteAware,
        WidgetsBindingObserver,
        AfterLayoutMixin<RecordControllerScreen> {
  final MobileControllerService mobileControllerService =
      injector<MobileControllerService>();
  final AudioService audioService = injector<AudioService>();
  final ConfigurationService configurationService =
      injector<ConfigurationService>();
  late RecordBloc recordBloc;
  late MeiliSearchBloc meiliSearchBloc;
  String? transcribedText;

  bool shouldShowMeiliSearch = false;

  late HighlightController textEditingController;

  @override
  void initState() {
    recordBloc = context.read<RecordBloc>();
    meiliSearchBloc = context.read<MeiliSearchBloc>();
    textEditingController = HighlightController();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.payload.isListening) {
      recordBloc.add(
        StartRecordingEvent(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register the route observer
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Unsubscribe from the route observer
    routeObserver.unsubscribe(this);
    // Stop the recording when disposing the screen
    recordBloc.add(StopRecordingEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        resizeToAvoidBottomInset: false,
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocProvider.value(
      value: recordBloc,
      child: BlocConsumer<RecordBloc, RecordState>(
        listener: (context, state) {
          // Update transcribedText when transcription is complete
          if (state is RecordProcessingState &&
              state.status == RecordProcessingStatus.transcribed &&
              state.transcription != null &&
              state.transcription!.isNotEmpty) {
            setState(() {
              transcribedText = state.transcription;
            });
          }

          // Reset transcribedText when starting new recording
          if (state is RecordRecordingState) {
            setState(() {
              transcribedText = null;
            });
          }

          if (state is RecordSuccessState) {
            final dp1Playlist = state.lastDP1Call;

            if (dp1Playlist == null) {
              final entity = state.lastIntent.entities?.firstOrNull;
              if (entity == null) {
                return;
              }
              switch (entity.type) {
                case AiEntityType.playlist:
                  final playlistId = entity.ids?.first;
                  if (playlistId == null) {
                    return;
                  }
                  injector<DP1FeedService>()
                      .getPlaylistById(playlistId)
                      .then((value) {
                    final dp1Playlist = value;
                    if (dp1Playlist.items.isEmpty) {
                      return;
                    }
                    injector<NavigationService>().navigateTo(
                      AppRouter.dp1PlaylistDetailsPage,
                      arguments: DP1PlaylistDetailsScreenPayload(
                        playlist: dp1Playlist,
                        backTitle: 'Index',
                      ),
                    );
                  });
                case AiEntityType.channel:
                  final channelId = entity.ids?.first;
                  if (channelId == null) {
                    return;
                  }
                  injector<DP1FeedService>()
                      .getChannelDetail(channelId)
                      .then((value) {
                    final channel = value;
                    if (channel.playlists.isEmpty) {
                      return;
                    }
                    injector<NavigationService>().navigateTo(
                      AppRouter.channelDetailPage,
                      arguments: ChannelDetailPagePayload(
                        channel: channel,
                      ),
                    );
                  });
                case AiEntityType.myCollection:
                  injector<NavigationService>().openMyCollection();
                  break;
                default:
                  return;
              }
            }

            if (dp1Playlist == null || dp1Playlist.items.isEmpty) {
              return;
            }
            injector<NavigationService>().navigateTo(
              AppRouter.dp1PlaylistDetailsPage,
              arguments: DP1PlaylistDetailsScreenPayload(
                playlist: dp1Playlist,
                backTitle: 'Index',
              ),
            );
          }
        },
        builder: (context, state) {
          return _recordView(context, state);
        },
      ),
    );
  }

  Widget _recordView(BuildContext context, RecordState state) {
    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top,
            ),
            SizedBox(
              height: UIConstants.topControlsBarHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Handle back button tap
                      injector<NavigationService>().goBack();
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: SvgPicture.asset(
                          'assets/images/close.svg',
                          width: 18.03,
                          colorFilter: const ColorFilter.mode(
                            AppColor.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            (shouldShowMeiliSearch)
                ? Expanded(
                    child: Container(
                    child: MeiliSearchPage(),
                  ))
                : Expanded(
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: state is RecordProcessingState
                                ? null
                                : () {
                                    context.read<RecordBloc>().add(
                                          state is RecordRecordingState
                                              ? StopRecordingEvent()
                                              : StartRecordingEvent(),
                                        );
                                  },
                            child: _recordButton(state),
                          ),
                        ),
                        const SizedBox(height: 105.52),
                        _recordTranscribedText(context, state),
                        _recordStatus(context, state),
                      ],
                    ),
                  ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom +
              MediaQuery.of(context).viewInsets.bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LLMTextInput(
                controller: textEditingController,
                active: true,
                enabled: !(state is RecordProcessingState ||
                    state is RecordRecordingState),
                autoFocus: !widget.payload.isListening,
                onSend: (text) {
                  recordBloc.add(
                    SubmitTextEvent(text),
                  );
                  setState(() {
                    shouldShowMeiliSearch = false;
                  });
                },
                onChanged: (text) {
                  final match = textEditingController.getMatchOrFull();
                  setState(() {
                    shouldShowMeiliSearch = text.isNotEmpty;
                  });
                  meiliSearchBloc.add(
                    MeiliSearchQueryChanged(text),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordButton(RecordState state) {
    final isRecording = state is RecordRecordingState;
    final isProcessing = state is RecordProcessingState;
    log.info(
      'RecordControllerScreen: _recordButton: isRecording: $isRecording, isProcessing: $isProcessing',
    );
    return ColoredBox(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: UIConstants.animationDuration,
        width: UIConstants.recordButtonSize,
        height: UIConstants.recordButtonSize,
        decoration: BoxDecoration(
          color: PrimitivesTokens.colorsLightBlue,
          shape: BoxShape.circle,
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: PrimitivesTokens.colorsLightBlue.withOpacity(0.4),
                    spreadRadius: UIConstants.recordButtonSpreadRadius,
                  ),
                ]
              : [],
        ),
      ),
    );
  }

  Widget _recordTranscribedText(BuildContext context, RecordState state) {
    if (transcribedText != null && transcribedText!.isNotEmpty) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(),
          ),
        ),
        child: _recordMessage(context, transcribedText!),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _recordStatus(BuildContext context, RecordState state) {
    switch (state.runtimeType) {
      case RecordRecordingState:
        return _recordProcessingStatus(
          MessageConstants.recordingText,
        );
      case RecordProcessingState:
        return _recordProcessingStatus(
          (state as RecordProcessingState).status.message,
        );
      case RecordSuccessState:
        if (!state.isValid) {
          return _recordErrorStatus(
            AudioException((state as RecordSuccessState).response).message,
          );
        }
      case RecordErrorState:
        {
          if ((state as RecordErrorState).error
              is AudioPermissionDeniedException) {
            return _noPermissionWidget(context);
          } else if (state.error is AudioException) {
            return _recordErrorStatus(
              (state.error as AudioException).message,
            );
          }
        }
    }

    return const SizedBox.shrink();
  }

  Widget _recordMessage(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: Theme.of(context).textTheme.small,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _noPermissionWidget(BuildContext context) {
    return Column(
      children: [
        Text(
          AudioExceptionType.permissionDenied.message,
          style: Theme.of(context).textTheme.small,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          text: 'Request Permission',
          onTap: () async {
            await injector<NavigationService>().openMicrophoneSettings();
          },
        ),
      ],
    );
  }

  Widget _recordProcessingStatus(String processingMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PrimitivesTokens.colorsLightBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  processingMessage,
                  style: Theme.of(context).textTheme.small,
                ),
                _AnimatedDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordErrorStatus(String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Text(
        errorMessage,
        style: Theme.of(context).textTheme.small.copyWith(
              color: PrimitivesTokens.colorsLightRed,
            ),
        textAlign: TextAlign.left,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AnimatedDots extends StatefulWidget {
  @override
  _AnimatedDotsState createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: 3).animate(_animationController);
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final buffer = StringBuffer();
        for (var i = 0; i < _animation.value; i++) {
          buffer.write('.');
        }
        return Text(
          buffer.toString(),
          style: Theme.of(context).textTheme.small,
        );
      },
    );
  }
}
