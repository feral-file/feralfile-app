import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_bloc.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_event.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddLocalFeedServerPage extends StatefulWidget {
  const AddLocalFeedServerPage({super.key});

  @override
  State<AddLocalFeedServerPage> createState() => _AddLocalFeedServerPageState();
}

class _AddLocalFeedServerPageState extends State<AddLocalFeedServerPage> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://dp1-feed-operator-api-dev.objkt-com.workers.dev',
    // 'http://192.168.31.21:8787',
  );
  final ScrollController _scrollController = ScrollController();
  late final AddLocalFeedServerBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = AddLocalFeedServerBloc();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels + 100 >=
          _scrollController.position.maxScrollExtent) {
        _bloc.add(const LoadMorePlaylistsEvent());
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _loadPlaylists() {
    final url = _urlController.text.trim();
    _bloc.add(LoadPlaylistsEvent(url));
  }

  void _addServer() {
    _bloc.add(const AddServerEvent());
  }

  void _clearError() {
    _bloc.add(const ClearErrorEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => _bloc,
      child: BlocListener<AddLocalFeedServerBloc, AddLocalFeedServerState>(
        listener: (context, state) {
          if (state.isAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully added server: ${state.serverUrl}'),
                backgroundColor: AppColor.primaryBlack,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: AppColor.auGreyBackground,
          appBar: const CustomAppBar(
            backTitle: 'Index',
          ),
          body: BlocBuilder<AddLocalFeedServerBloc, AddLocalFeedServerState>(
            builder: (context, state) {
              return Column(
                children: [
                  // URL Input Section
                  Container(
                    padding: EdgeInsets.all(ResponsiveLayout.paddingHorizontal),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server URL',
                          style: theme.textTheme.ppMori400White14,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _urlController,
                          style: theme.textTheme.ppMori400White14,
                          decoration: InputDecoration(
                            hintText: 'https://your-dp1-server.com',
                            hintStyle: theme.textTheme.ppMori400Grey12,
                            filled: true,
                            fillColor: AppColor.primaryBlack,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColor.disabledColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColor.disabledColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: AppColor.white),
                            ),
                          ),
                          onSubmitted: (_) => _loadPlaylists(),
                          onChanged: (_) {
                            if (state.hasError) {
                              _clearError();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : _loadPlaylists,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.white,
                              foregroundColor: AppColor.primaryBlack,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: state.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColor.primaryBlack,
                                    ),
                                  )
                                : Text(
                                    'Load Playlists',
                                    style: theme.textTheme.ppMori400Black14,
                                  ),
                          ),
                        ),
                        if (state.hasError) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Text(
                              state.error!.message,
                              style: theme.textTheme.ppMori400Grey12.copyWith(
                                color: AppColor.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Playlists Preview Section
                  if (state.hasPlaylists) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveLayout.paddingHorizontal),
                      child: Row(
                        children: [
                          Text(
                            'Found ${state.playlists.length} playlists',
                            style: theme.textTheme.ppMori400White14,
                          ),
                          const Spacer(),
                          Text(
                            'Preview',
                            style: theme.textTheme.ppMori400Grey12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollController,
                        shrinkWrap: true,
                        slivers: [
                          UIHelper.playlistSliverListView(
                            playlists: state.playlists
                                .map((playlist) => PlaylistReference(
                                    playlist: playlist, url: state.serverUrl!))
                                .toList(),
                            channelVisible: false,
                          ),
                          if (state.isLoadingMore)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    ResponsiveLayout.pageHorizontalEdgeInsets,
                                child: const Center(
                                    child:
                                        LoadMoreIndicator(isLoadingMore: true)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else if (!state.isLoading && state.isInitial) ...[
                    // Empty state when no playlists loaded
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.music_note_outlined,
                              size: 64,
                              color: AppColor.disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Enter a DP1 server URL to preview playlists',
                              style: theme.textTheme.ppMori400Grey14,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Add Server Button
                  if (state.hasPlaylists)
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveLayout.paddingHorizontal),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state.isAdding ? null : _addServer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primaryBlack,
                            foregroundColor: AppColor.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColor.white),
                          ),
                          child: state.isAdding
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColor.white,
                                  ),
                                )
                              : Text(
                                  'Add Server to Feral File',
                                  style: theme.textTheme.ppMori400White14,
                                ),
                        ),
                      ),
                    ),
                  const BottomSpacing(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
