import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/works/bloc/works_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorksPage extends StatefulWidget {
  const WorksPage({super.key});

  @override
  State<WorksPage> createState() => WorksPageState();
}

class WorksPageState extends State<WorksPage>
    with AutomaticKeepAliveClientMixin {
  late final WorksBloc _worksBloc;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _worksBloc = injector<WorksBloc>();
    _scrollController = ScrollController();
    _worksBloc.add(const LoadWorksEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollPositionChanged(ScrollPosition position) {
    // Handle scroll position update from parent
    if (position.pixels + 100 >= position.maxScrollExtent &&
        position.maxScrollExtent > 0) {
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
    if (state.isLoading && state.nowDisplayingItems.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.nowDisplayingItems.isEmpty) {
      return ErrorView(
        error: 'Error loading works: ${state.error}',
        onRetry: () => _worksBloc.add(const LoadWorksEvent()),
      );
    }

    return _buildWorksGridView(state);
  }

  Widget _buildWorksGridView(WorksState state) {
    final nowDisplayingItems = state.nowDisplayingItems;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;

    return _LoadMoreListener(
      onScrollPositionChanged: _onScrollPositionChanged,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        controller: _scrollController,
        slivers: [
          UIHelper.dp1ItemSliverGrid(context, nowDisplayingItems, 'Works'),
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
          const SliverToBoxAdapter(child: BottomSpacing()),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Generic scroll listener widget for nested scroll hierarchies
/// Listens to parent scroll position and passes updates to callback
class _LoadMoreListener extends StatefulWidget {
  const _LoadMoreListener({
    required this.child,
    required this.onScrollPositionChanged,
  });

  final Widget child;
  final void Function(ScrollPosition) onScrollPositionChanged;

  @override
  State<_LoadMoreListener> createState() => _LoadMoreListenerState();
}

class _LoadMoreListenerState extends State<_LoadMoreListener> {
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    try {
      // Remove old listener if exists
      _scrollPosition?.removeListener(_onScroll);

      // Get parent Scrollable position
      final scrollableState = Scrollable.of(context);
      _scrollPosition = scrollableState.position;

      // Add listener
      _scrollPosition?.addListener(_onScroll);
    } catch (e) {
      // Scrollable not found in widget tree
    }
  }

  void _onScroll() {
    if (!mounted) {
      _scrollPosition?.removeListener(_onScroll);
      return;
    }

    final position = _scrollPosition;
    if (position == null) return;

    // Notify parent about position change
    widget.onScrollPositionChanged(position);
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
