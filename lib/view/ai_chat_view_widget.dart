import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/custom_chat_input_widget.dart'; // Add this import
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

const aiChatUser = types.User(id: 'user');
const aiChatBot = types.User(id: 'aiBot');

class AiChatViewWidget extends StatefulWidget {
  const AiChatViewWidget({
    required this.onMessage,
    super.key,
    this.initialMessages = const [],
    this.messageLimit = 1,
  });

  final List<types.Message> initialMessages;
  final Future<void> Function(String message) onMessage;
  final int? messageLimit; // New: Optional message limit

  @override
  State<AiChatViewWidget> createState() => _AiChatViewWidgetState();
}

class _AiChatViewWidgetState extends State<AiChatViewWidget> {
  final TextEditingController _textController = TextEditingController()
    ..text = kDebugMode
        ? 'Please show 5 film by Aaron Penne and Aaron Penne x Boreta and Alexis André'
        : '';
  String _sendIcon = 'assets/images/sendMessage.svg';

  late final List<types.Message>
      _messages; // Re-introduced: This list is now managed internally

  late RecordBloc recordBloc;
  String?
      _currentProcessingMessageId; // To keep track of the processing bot message
  String? _currentUserMessageId; // To keep track of the user's message ID

  bool get _isProcessing =>
      _currentProcessingMessageId != null; // Add this line

  @override
  void initState() {
    recordBloc = context.read<RecordBloc>();
    _messages =
        widget.initialMessages.toList(); // Initialize with initial messages
    super.initState();
    // Unfocus the input after the initial build, and when returning to the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    // _textController.dispose(); // Retained in previous diff for some reason, will remove this comment
    _textController.dispose();
    super.dispose();
  }

  int get _userMessageCount => _messages
      .where((msg) => msg.author.id == aiChatUser.id)
      .length; // Use internal _messages list

  bool get _isInputEnabled {
    if (widget.messageLimit == null) {
      return true; // No limit, always enabled
    }
    return _userMessageCount < widget.messageLimit!; // Enabled if under limit
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<RecordBloc, RecordState>(
      listener: (context, state) {
        if (state is RecordProcessingState) {
          if (state.status == RecordProcessingStatus.transcribed) {
            final userMessage = types.TextMessage(
              author: aiChatUser,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              text: state.transcription!,
              status: types.Status.delivered,
              showStatus: false,
            );
            if (_currentUserMessageId == null) {
              _messages.add(userMessage);
            }
          }

          final newProcessingMessage = types.TextMessage(
            author: aiChatBot,
            createdAt: DateTime.now().millisecondsSinceEpoch + 1,
            id: _currentProcessingMessageId ?? const Uuid().v4(),
            // Use existing ID or generate new
            text: state.processingMessage,
            status: types.Status.sending, // Ensure status is sending
          );

          setState(() {
            if (_currentProcessingMessageId == null) {
              // Add to _messages which is a mutable list from parent
              _messages.add(newProcessingMessage);
              _currentProcessingMessageId = newProcessingMessage.id;
            } else {
              // Update existing processing message in _messages
              final index = _messages
                  .indexWhere((msg) => msg.id == _currentProcessingMessageId);
              if (index != -1) {
                _messages[index] = newProcessingMessage;
              }
            }
          });
        } else if (state is RecordSuccessState) {
          setState(() {
            // Update user message status to delivered
            final userMessageIndex =
                _messages.indexWhere((msg) => msg.id == _currentUserMessageId);
            if (userMessageIndex != -1) {
              _messages[userMessageIndex] =
                  (_messages[userMessageIndex] as types.TextMessage).copyWith(
                      text: state.transcription,
                      status:
                          types.Status.delivered); // Update with transcription
            }

            // Remove processing message
            if (_currentProcessingMessageId != null) {
              _messages
                  .removeWhere((msg) => msg.id == _currentProcessingMessageId);
              _currentProcessingMessageId = null;
            }

            // Add bot's actual response
            _messages.add(
              types.TextMessage(
                author: aiChatBot,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                id: const Uuid().v4(),
                text: state.response,
                status: types.Status.delivered,
                showStatus: false,
              ),
            );
            _currentUserMessageId = null; // Clear user message ID
          });
        } else if (state is RecordErrorState) {
          if (!(state.error is AudioRecordingFailedException ||
              state.error is AudioPermissionDeniedException ||
              state.error is AudioRecordNoSpeechException ||
              state.error is AudioFileNotFoundException))
            setState(() {
              // Update user message status to error
              final userMessageIndex = _messages
                  .indexWhere((msg) => msg.id == _currentUserMessageId);
              if (userMessageIndex != -1) {
                _messages[userMessageIndex] =
                    (_messages[userMessageIndex] as types.TextMessage)
                        .copyWith(status: types.Status.error);
              }

              // Remove processing message
              if (_currentProcessingMessageId != null) {
                _messages.removeWhere(
                    (msg) => msg.id == _currentProcessingMessageId);
                _currentProcessingMessageId = null;
              }

              // Add bot's error message
              _messages.add(
                types.TextMessage(
                  author: aiChatBot,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  id: const Uuid().v4(),
                  text: '${(state.error as AudioException).message}',
                  // Localize this if possible
                  status: types.Status.error,
                ),
              );
              _currentUserMessageId = null; // Clear user message ID
            });
        }
      },
      child: Chat(
        // l10n: ChatL10nEn(
        //   inputPlaceholder: 'Ask me to display art',
        // ),
        messages: _messages.reversed.toList(),
        // Use internal _messages list
        customMessageBuilder: _customMessageBuilder,
        avatarBuilder: (types.User user) {
          if (user.id == aiChatUser.id) {
            return SizedBox();
          } else if (user.id == aiChatBot.id) {
            return Container(
              color: Colors.amber,
            );
          }
          return const SizedBox.shrink();
        },
        dateHeaderBuilder: (dateHeader) {
          return SizedBox();
        },
        bubbleBuilder: _bubbleBuilder,
        onSendPressed: _handleSendPressed,
        user: aiChatUser,
        customBottomWidget: _isInputEnabled
            ? Padding(
                padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                child: CustomChatInputWidget(
                  // Replace Input with CustomChatInputWidget
                  onSendPressed: _handleSendPressed,
                  textEditingController: _textController,
                  isProcessing: _isProcessing, // Pass isProcessing state
                ),
              )
            : const SizedBox(),
        // Disabled input or message when limit reached
        theme: _chatTheme,
        emptyState: Center(
          child: Text(
            'How can I help you display art?',
            style: theme.textTheme.ppMori700White14,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    if (!_isInputEnabled) {
      return; // Do not send if input is disabled
    }

    final userMessage = types.TextMessage(
      author: aiChatUser,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
      status: types.Status.sending, // Set initial status to sending
    );

    setState(() {
      _messages
          .add(userMessage); // Add user message immediately to internal list
      _currentUserMessageId = userMessage.id; // Store user message ID
      // Ensure _currentProcessingMessageId is set before calling onMessage
      // This message will be updated/removed by the BlocListener
      _currentProcessingMessageId = const Uuid().v4();
      _messages.add(types.TextMessage(
        author: aiChatBot,
        createdAt: DateTime.now().millisecondsSinceEpoch + 1,
        id: _currentProcessingMessageId!,
        text: 'Processing...',
      ));
      _textController.clear();
      _sendIcon = 'assets/images/sendMessage.svg';
    });

    // Call the onMessage callback which is expected to dispatch the BLoC event
    widget.onMessage(message.text);

    FocusScope.of(context).unfocus(); // Unfocus the input field
  }

  DefaultChatTheme get _chatTheme {
    final theme = Theme.of(context);
    return DefaultChatTheme(
      messageInsetsVertical: 6,
      messageInsetsHorizontal: 0,
      errorIcon: const SizedBox(),
      bubbleMargin: ResponsiveLayout.pageHorizontalEdgeInsets,
      backgroundColor: Colors.transparent,
      sendButtonIcon: SvgPicture.asset(
        _sendIcon,
      ),
      emptyChatPlaceholderTextStyle: theme.textTheme.ppMori400White12
          .copyWith(color: AppColor.auQuickSilver),
      statusIconPadding: EdgeInsets.zero,
      dateDividerMargin: const EdgeInsets.symmetric(vertical: 0),
      dateDividerTextStyle:
          theme.textTheme.dateDividerTextStyle.copyWith(color: Colors.amber),
      primaryColor: Colors.transparent,
      sentMessageBodyTextStyle: theme.textTheme.ppMori400White12,
      secondaryColor: AppColor.chatSecondaryColor,
      receivedMessageBodyTextStyle: theme.textTheme.ppMori400White12
          .copyWith(color: AppColor.feralFileLightBlue),
      receivedMessageDocumentIconColor: Colors.transparent,
      sentMessageDocumentIconColor: Colors.transparent,
      documentIcon: SvgPicture.asset(
        'assets/images/bug_icon.svg',
        width: 20,
      ),
      sentMessageCaptionTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.sentMessageCaptionTextStyle
          : theme.textTheme.sentMessageCaptionTextStyle16,
      receivedMessageCaptionTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.receivedMessageCaptionTextStyle
          : theme.textTheme.receivedMessageCaptionTextStyle16,
      sendingIcon: Container(
        width: 16,
        height: 12,
        padding: const EdgeInsets.only(left: 3),
        child: const CircularProgressIndicator(
          color: AppColor.secondarySpanishGrey,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _customMessageBuilder(
    types.CustomMessage message, {
    required int messageWidth,
  }) {
    final text = message.metadata.toString();
    return Text(text);
  }

  Widget _bubbleBuilder(
    Widget child, {
    required types.Message message,
    required bool nextMessageInGroup,
  }) {
    return child;
  }
}
