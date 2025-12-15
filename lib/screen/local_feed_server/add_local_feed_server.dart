import 'dart:async';

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_bloc.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_event.dart';
import 'package:autonomy_flutter/screen/local_feed_server/bloc/add_local_feed_server_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
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

  Future<void> _loadPlaylists() async {
    final completer = Completer<void>();
    final url = _urlController.text.trim();
    _bloc.add(LoadPlaylistsEvent(url,
        onComplete: completer.complete, onError: completer.complete));
    await completer.future;
  }

  Future<void> _addServer() async {
    final completer = Completer<void>();
    _bloc.add(AddServerEvent(
        onComplete: completer.complete, onError: completer.complete));
    await completer.future;
  }

  void _clearErrorAndReset() {
    _bloc.add(const ClearErrorEvent());
    _bloc.add(const ResetEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => _bloc,
      child: BlocListener<AddLocalFeedServerBloc, AddLocalFeedServerState>(
        listener: (context, state) {
          if (state.isAdded) {
            UIHelper.showInfoDialog(context, 'Server added successfully',
                    'Your server has been added successfully.')
                .then((value) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        },
        child: Scaffold(
          backgroundColor: AppColor.auGreyBackground,
          appBar: const MainAppBar(
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
                          style: AppTypography.body(context).white,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _urlController,
                          style: AppTypography.body(context).white,
                          decoration: InputDecoration(
                            hintText: 'https://your-dp1-server.com',
                            hintStyle: AppTypography.body(context).grey,
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
                            _clearErrorAndReset();
                          },
                        ),
                        if (state.hasError) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              state.error!.message,
                              style: AppTypography.body(context)
                                  .grey
                                  .copyWith(
                                    color: AppColor.red,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (state.isInitial ||
                            state.isLoading ||
                            state.isError) ...[
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryAsyncButton(
                              text: 'Load Playlists',
                              onTap: state.isLoading ? null : _loadPlaylists,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),

                  // Playlists Preview Section
                  if (state.hasPlaylists) ...[
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
                              style: AppTypography.body(context).grey,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (state.isLoading) ...[
                    const SizedBox(height: 16),
                    LoadingWidget(backgroundColor: AppColor.auGreyBackground),
                  ] else if (state.isError) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Error loading playlists',
                      style: AppTypography.body(context).grey,
                      textAlign: TextAlign.center,
                    ),
                  ] else if (state.playlists.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'No playlists found',
                      style: AppTypography.body(context).grey,
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Add Server Button
                  if (state.hasPlaylists)
                    Container(
                      padding:
                          EdgeInsets.all(ResponsiveLayout.paddingHorizontal),
                      child: SizedBox(
                        width: double.infinity,
                        child: PrimaryAsyncButton(
                          text: 'Add',
                          onTap: state.isAdding ? null : _addServer,
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
