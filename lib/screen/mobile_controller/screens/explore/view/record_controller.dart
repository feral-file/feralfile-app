import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/record_processing_status_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/ai_chat_thread_view.dart';
import 'package:autonomy_flutter/view/ai_chat_view_widget.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_svg/svg.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:uuid/uuid.dart';

ValueNotifier<bool> chatModeNotifier = ValueNotifier<bool>(false);

class RecordControllerScreen extends StatefulWidget {
  const RecordControllerScreen({super.key});

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

  @override
  void initState() {
    recordBloc = context.read<RecordBloc>();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    recordBloc.add(
      StartRecordingEvent(),
    );
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
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: chatModeNotifier,
      builder: (context, chatModeView, child) {
        return BlocProvider.value(
          value: recordBloc,
          child: BlocConsumer<RecordBloc, RecordState>(
            listener: (context, state) {
              if (state is RecordSuccessState) {
                final dp1Playlist = state.lastDP1Call;
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
              return IndexedStack(index: chatModeView ? 0 : 1, children: [
                _aiChatThreadView(
                  context,
                  state is RecordSuccessState ? state : null,
                ),
                _recordView(context, state)
              ]);
            },
          ),
        );
      },
    );
  }

  Widget _recordView(BuildContext context, RecordState state) {
    return Column(
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
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        right: 15, top: 16, left: 15, bottom: 16),
                    child: SvgPicture.asset(
                      'assets/images/close.svg',
                      width: 22,
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
        Expanded(
          flex: 6,
          child: Center(
            child: Column(
              children: [
                // const SizedBox(height: 60),
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
                    child: _askAnythingWidget(
                      context,
                      state,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                  child: Column(
                    children: [
                      Builder(
                        builder: (context) {
                          if (state is RecordSuccessState &&
                              state.lastDP1Call!.items.isEmpty) {
                            return _errorWidget(
                              context,
                              AudioException(state.response),
                            );
                          }
                          if (state is RecordErrorState) {
                            if (state.error is AudioPermissionDeniedException) {
                              return _noPermissionWidget(context);
                            } else if (state.error is AudioException) {
                              return _errorWidget(
                                context,
                                state.error as AudioException,
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: _historyChat(context),
        ),
      ],
    );
  }

  Widget _aiChatThreadView(BuildContext context, RecordSuccessState? state) {
    final messages = <types.Message>[];
    if (state != null) {
      final userMessage = types.TextMessage(
        author: aiChatUser,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: state.transcription,
      );
      final aiBotMessage = types.TextMessage(
        author: aiChatBot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: state.response,
      );
      messages.addAll([userMessage, aiBotMessage]);
    }

    return Column(
      children: [
        Container(
          color: AppColor.primaryBlack,
          height: 130 + MediaQuery.of(context).padding.top,
        ),
        AiChatThreadView(
          initialMessages: [],
        ),
        ValueListenableBuilder(
          valueListenable: nowDisplayingShowing,
          builder: (context, value, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: MediaQuery.of(context).padding.bottom +
                  UIConstants.nowDisplayingBarBottomPadding +
                  (value ? (kNowDisplayingHeight + 8) : 0),
            );
          },
        )
      ],
    );
  }

  Widget _askAnythingWidget(BuildContext context, RecordState state) {
    final isRecording = state is RecordRecordingState;
    final isProcessing = state is RecordProcessingState;
    final text = isRecording
        ? MessageConstants.recordingText
        : isProcessing
            ? state.status.message
            : MessageConstants.askAnythingText;
    log.info(
      'RecordControllerScreen: _askAnythingWidget: isRecording: $isRecording, isProcessing: $isProcessing, text: $text---',
    );
    return ColoredBox(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: UIConstants.animationDuration,
        width: isRecording
            ? UIConstants.recordButtonSizeActive
            : UIConstants.recordButtonSize,
        height: isRecording
            ? UIConstants.recordButtonSizeActive
            : UIConstants.recordButtonSize,
        decoration: BoxDecoration(
          color: AppColor.feralFileLightBlue,
          shape: BoxShape.circle,
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: AppColor.feralFileLightBlue.withOpacity(0.7),
                    blurRadius: 50,
                    spreadRadius: 20,
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.ppMori400Black12,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _historyChat(BuildContext context) {
    var messages = configurationService.getRecordedMessages();
    if (kDebugMode && messages.isEmpty) {
      messages = UIConstants.sampleHistoryAsks;
    }

    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: messages.length + 1,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return const SizedBox(height: 100);
            }

            final theme = Theme.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: ResponsiveLayout.paddingAll,
                  child: Text(
                    messages[index],
                    style: theme.textTheme.ppMori400Grey12,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                addDivider(color: AppColor.primaryBlack, height: 1),
              ],
            );
          },
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: MultiValueListenableBuilder(
            valueListenables: [
              nowDisplayingShowing,
            ],
            builder: (context, values, _) {
              return values.every((value) => value as bool)
                  ? Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.37, 0.37],
                              colors: [
                                AppColor.auGreyBackground.withAlpha(0),
                                AppColor.auGreyBackground,
                                AppColor.auGreyBackground,
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container();
            },
          ),
        ),
      ],
    );
  }

  Widget _noPermissionWidget(BuildContext context) {
    return Column(
      children: [
        Text(
          AudioExceptionType.permissionDenied.message,
          style: Theme.of(context).textTheme.ppMori400White12,
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

  Widget _errorWidget(BuildContext context, AudioException error) {
    return Center(
      child: Text(
        error.message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.ppMori400White12,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
