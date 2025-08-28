import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/works/bloc/works_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => _WorksPageState();
}

class _WorksPageState extends State<WorksPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final WorksBloc _worksBloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _worksBloc = injector<WorksBloc>();
    _worksBloc.add(const LoadWorksEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _worksBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _worksBloc.add(const LoadMoreWorksEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WorksBloc, WorksState>(
      bloc: _worksBloc,
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            _worksBloc.add(const RefreshWorksEvent());
            // Wait for the refresh to complete
            await _worksBloc.stream.firstWhere(
              (state) => state.isLoaded || state.isError,
            );
          },
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: _buildContent(state),
        );
      },
    );
  }

  Widget _buildContent(WorksState state) {
    if (state.isLoading && state.assetTokens.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.assetTokens.isEmpty) {
      return ErrorView(
        error: 'Error loading works: ${state.error}',
        onRetry: () => _worksBloc.add(const LoadWorksEvent()),
      );
    }

    return _buildWorksGridView(state);
  }

  Widget _buildWorksGridView(WorksState state) {
    final assetTokens = state.assetTokens;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        UIHelper.assetTokenSliverGrid(context, assetTokens, 'Works'),
        if (hasMore || isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: hasMore
                    ? LoadMoreIndicator(isLoadingMore: isLoadingMore)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
