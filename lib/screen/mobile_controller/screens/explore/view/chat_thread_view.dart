import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/intent.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_item.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/dp1_playlist_grid_view.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';

class ChatThreadView extends StatefulWidget {
  const ChatThreadView({super.key, required this.state});

  final RecordSuccessState state;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  late DP1Call playlist;
  late DP1Intent intent;

  @override
  void initState() {
    super.initState();
    playlist = widget.state.lastDP1Call!;
    intent = widget.state.lastIntent!;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: _content(context),
            flex: 2,
          ),
          Expanded(child: _chatThread(context)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return PlaylistItem(playlist: playlist);
  }

  Widget _content(BuildContext context) {
    return PlaylistAssetGridView(
      playlist: playlist,
    );
  }

  Widget _chatThread(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.state.transcription;
    final response = widget.state.response;
    return Padding(
      padding: ResponsiveLayout.pageHorizontalEdgeInsets,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                message,
                style: theme.textTheme.ppMori400White12,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 100),
            child: Text(
              response,
              style: theme.textTheme.ppMori400Black12.copyWith(
                color: AppColor.feralFileLightBlue,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
