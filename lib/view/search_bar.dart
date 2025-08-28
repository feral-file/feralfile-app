import 'dart:async';

import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/debouce_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AuSearchBar extends StatefulWidget {
  final Function(String)? onChanged;
  final Function(String)? onSearch;
  final Function(String)? onClear;
  final TextEditingController? controller;
  final int minSearchLength;
  final int minSearchLengthWhenPressEnter;

  const AuSearchBar(
      {super.key,
      this.onChanged,
      this.onSearch,
      this.onClear,
      this.controller,
      this.minSearchLength = 0,
      this.minSearchLengthWhenPressEnter = 0});

  @override
  State<AuSearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<AuSearchBar>
    with RouteAware, WidgetsBindingObserver {
  late TextEditingController _controller;
  final _focusNode = FocusNode();
  Timer? _timer;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    // _focusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
    routeObserver.unsubscribe(this);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColor.auGreyBackground,
        borderRadius: BorderRadius.circular(5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: theme.textTheme.ppMori400White12,
                cursorColor: AppColor.white,
                cursorWidth: 0.5,
                cursorHeight: 17,
                decoration: InputDecoration(
                  // contentPadding: const EdgeInsets.only(bottom: 10),
                  hintText: 'search_by_'.tr(),
                  hintStyle: theme.textTheme.ppMori400Grey12
                      .copyWith(color: AppColor.auQuickSilver),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  widget.onChanged?.call(value);
                  // we allow search when user type at least 3 characters
                  if (value.length >= widget.minSearchLength || value.isEmpty) {
                    _timer?.cancel();
                    _timer = Timer(const Duration(milliseconds: 300), () {
                      _callOnSearch(value);
                    });
                  }
                },
                onSubmitted: (value) {
                  // we allow search when user type at least 2 characters and press enter
                  if (value.length >= widget.minSearchLengthWhenPressEnter ||
                      value.isEmpty) {
                    _callOnSearch(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _callOnSearch(String value) {
    withDebounce(() {
      widget.onSearch?.call(value.trim());
    }, key: 'searchBarKey', debounceTime: 300);
  }
}

class ActionBar extends StatefulWidget {
  final AuSearchBar searchBar;
  final Function()? onCancel;

  const ActionBar({required this.searchBar, super.key, this.onCancel});

  @override
  State<ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<ActionBar> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: widget.searchBar,
          ),
          if (widget.onCancel != null)
            IconButton(
              icon: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(
                  AuIcon.close,
                  size: 18,
                  color: AppColor.white,
                ),
              ),
              constraints: const BoxConstraints(maxWidth: 44, maxHeight: 44),
              onPressed: () {
                widget.onCancel?.call();
              },
            )
        ],
      );
}
