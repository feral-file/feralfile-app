// import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/screen/playlists/add_new_playlist/add_new_playlist.dart';
import 'package:autonomy_flutter/view/au_button_clipper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class EditPlaylistGridView extends StatefulWidget {
  final List<CompactedAssetToken?> tokens;
  final ScrollController? controller;
  final Function(String tokenID, bool value)? onChangedSelect;
  final List<String>? selectedTokens;
  final Function(List<CompactedAssetToken?>) onReorder;
  final Function()? onAddTap;

  const EditPlaylistGridView({
    required this.tokens,
    required this.onReorder,
    super.key,
    this.controller,
    this.onChangedSelect,
    this.selectedTokens,
    this.onAddTap,
  });

  @override
  State<EditPlaylistGridView> createState() => _EditPlaylistGridViewState();
}

class _EditPlaylistGridViewState extends State<EditPlaylistGridView> {
  final int cellPerRowPhone = 3;
  final int cellPerRowTablet = 6;
  final double cellSpacing = 3;
  late int cellPerRow;

  @override
  void initState() {
    cellPerRow = ResponsiveLayout.isMobile ? cellPerRowPhone : cellPerRowTablet;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final estimatedCellWidth = MediaQuery.of(context).size.width / cellPerRow -
        cellSpacing * (cellPerRow - 1);
    final cachedImageSize = (estimatedCellWidth * 3).ceil();
    return ReorderableGridView.count(
      controller: widget.controller,
      onDragStart: (dragIndex) {
        // Vibrate.feedback(FeedbackType.light);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          final element = widget.tokens.removeAt(oldIndex);
          if (element != null) {
            widget.tokens.insert(newIndex, element);
          }
          widget.tokens.removeWhere((element) => element == null);
        });
        widget.onReorder.call(List.from(widget.tokens));
      },
      crossAxisCount: cellPerRow,
      crossAxisSpacing: cellSpacing,
      mainAxisSpacing: cellSpacing,
      children: widget.tokens
          .map(
            (e) => e != null
                ? ThumbnailPlaylistItem(
                    key: ValueKey(e),
                    token: e,
                    cachedImageSize: cachedImageSize,
                    showTriggerOrder: true,
                    isSelected: widget.selectedTokens?.contains(e.id) ?? false,
                    onChanged: (value) {
                      widget.onChangedSelect?.call(e.id, value ?? false);
                    },
                  )
                : const SizedBox.shrink(),
          )
          .toList(),
    );
  }
}

class AddTokenWidget extends StatelessWidget {
  const AddTokenWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipPath(
      clipper: AutonomyTopRightRectangleClipper(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: Center(
          child: SvgPicture.asset(
            'assets/images/joinFile.svg',
            colorFilter: ColorFilter.mode(theme.primaryColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
