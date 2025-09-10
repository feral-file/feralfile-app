import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/feralfile_home/filter_bar.dart';
import 'package:autonomy_flutter/screen/feralfile_home/sort_bar.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/search_bar.dart';
import 'package:flutter/material.dart';

class ExploreBar extends StatefulWidget {
  final void Function(
    String?,
    Map<FilterType, FilterValue> filters,
    SortBy sortBy,
  ) onUpdate;
  final FeralfileHomeTab tab;

  const ExploreBar(
      {required this.onUpdate,
      super.key,
      this.tab = FeralfileHomeTab.artworks});

  @override
  State<ExploreBar> createState() => _ExploreBarState();
}

class _ExploreBarState extends State<ExploreBar> {
  final TextEditingController _controller = TextEditingController();
  late final ValueNotifier<Map<FilterType, FilterValue>> _filters;
  late final ValueNotifier<SortBy> _sortBy;
  late final ValueNotifier<String?> _searchText;

  @override
  void initState() {
    super.initState();
    _searchText = ValueNotifier(null);
    _filters = ValueNotifier({});
    _sortBy = ValueNotifier(
        widget.tab.getDefaultSortBy(isSearching: _controller.text.isNotEmpty));
    _addListeners();
  }

  void _update() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.onUpdate(_searchText.value, _filters.value, _sortBy.value);
    });
  }

  void _addListeners() {
    _searchText.addListener(() {
      _update();
    });
    _filters.addListener(() {
      _update();
    });
    _sortBy.addListener(() {
      _update();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _searchText.dispose();
    _filters.dispose();
    _sortBy.dispose();
  }

  void _onSearch(String? value) {
    _searchText.value = value;
  }

  @override
  void didUpdateWidget(covariant ExploreBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != oldWidget.tab) {
      _sortBy.value =
          widget.tab.getDefaultSortBy(isSearching: _controller.text.isNotEmpty);
      _filters.value = {};
      _searchText.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCancel =
        _searchText.value != null && _searchText.value!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FFSearchBar(
            controller: _controller,
            onSearch: (value) {
              _onSearch(value);
            },
            onChanged: (value) {},
            onCancel: canCancel
                ? () {
                    _controller.clear();
                    _onSearch(null);
                  }
                : null,
            minSearchLength: 3,
            minSearchLengthWhenPressEnter: 2,
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterBar(
                filters: widget.tab.getFilterBy(),
                onFilterSelected: (type, value) {
                  log.info('Filter selected: $type, $value');
                  _filters.value = {..._filters.value, type: value};
                },
                onFilterCleared: (type) {
                  log.info('Filter cleared: $type');
                  _filters.value = {..._filters.value}..remove(type);
                },
              ),
              const Spacer(),
              SortBar(
                sortBys: widget.tab.getSortBy(
                    isSearching: _searchText.value != null &&
                        _searchText.value!.isNotEmpty),
                defaultSortBy: widget.tab.getDefaultSortBy(
                    isSearching: _searchText.value != null &&
                        _searchText.value!.isNotEmpty),
                onSortSelected: (sortBy) {
                  log.info('Sort selected: $sortBy');
                  _sortBy.value = sortBy;
                },
              )
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
