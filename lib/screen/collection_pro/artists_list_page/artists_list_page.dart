//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//
import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/nft_collection/models/predefined_collection_model.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_screen.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/header.dart';
import 'package:autonomy_flutter/view/paging_bar.dart';
import 'package:autonomy_flutter/view/predefined_collection/predefined_collection_item.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ArtistsListPage extends StatefulWidget {
  final ArtistsListPagePayload payload;

  const ArtistsListPage({required this.payload, super.key});

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
  final ScrollController _scrollController = ScrollController();
  final List<PredefinedCollectionModel> _items = [];
  final ValueNotifier<String?> _selectedCharacter = ValueNotifier(null);
  final _itemHeight = PredefinedCollectionItem.height + 1;
  static const int _scrollDuration = 500;
  static const int _scrollLag = 10;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _items.addAll(widget.payload.listPredefinedCollectionByArtist);

    _selectedCharacter.value = _items.first.name.firstSearchCharacter;

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_isDragging) {
      return;
    }
    double offset = _scrollController.offset;
    final targetIndex = (offset / _itemHeight).floor();
    if (targetIndex < 0 || targetIndex >= _items.length) {
      return;
    }
    final selectedCharacter = _items[targetIndex].name.firstSearchCharacter;
    _selectedCharacter.value = selectedCharacter;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColor.primaryBlack,
        appBar: _getAppBar(context),
        body: _body(context),
      );

  AppBar _getAppBar(BuildContext context) => getFFAppBar(
        context,
        onBack: () => Navigator.pop(context),
        title: HeaderView(
          title: 'artists'.tr(),
          padding: EdgeInsets.zero,
        ),
        action: const SizedBox(),
      );

  Widget _body(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          children: [
            ValueListenableBuilder<String?>(
                valueListenable: _selectedCharacter,
                builder: (context, value, child) => PagingBar(
                      onTap: (a) async {
                        final index = _items.indexWhere((element) =>
                            element.name.firstSearchCharacter == a);
                        if (index == -1) {
                          final nearestIndex = _items.lastIndexWhere(
                              (element) =>
                                  element.name.firstSearchCharacter
                                      .compareSearchKey(a) <
                                  0);
                          if (nearestIndex == -1) {
                            await _scrollTo(0);
                          } else {
                            await _scrollTo(nearestIndex * _itemHeight);
                          }
                        } else {
                          await _scrollTo(index * _itemHeight);
                        }
                        Future.delayed(const Duration(milliseconds: _scrollLag),
                            () {
                          _selectedCharacter.value = a;
                        });
                      },
                      onDragEnd: () {
                        Future.delayed(
                            const Duration(
                                milliseconds: _scrollDuration + _scrollLag),
                            () {
                          _isDragging = false;
                        });
                      },
                      onDragging: () {
                        _isDragging = true;
                      },
                      selectedCharacter: value,
                    )),
            Expanded(
                child: ListView.separated(
              controller: _scrollController,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final predefinedCollection = _items[index];
                return PredefinedCollectionItem(
                  predefinedCollection: predefinedCollection,
                  type: PredefinedCollectionType.artist,
                  searchStr: '',
                );
              },
              separatorBuilder: (BuildContext context, int index) =>
                  addOnlyDivider(color: AppColor.auGreyBackground),
            )),
          ],
        ),
      );

  Future<void> _scrollTo(double offset) async {
    await _scrollController.animateTo(
        min(_scrollController.position.maxScrollExtent, offset),
        duration: const Duration(milliseconds: _scrollDuration),
        curve: Curves.easeIn);
  }
}

class ArtistsListPagePayload {
  final List<PredefinedCollectionModel> listPredefinedCollectionByArtist;

  ArtistsListPagePayload(this.listPredefinedCollectionByArtist);
}
