import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_item.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/dp1_playlist_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DP1ResponseVisualView extends StatefulWidget {
  const DP1ResponseVisualView({super.key});

  @override
  State<DP1ResponseVisualView> createState() => _DP1ResponseVisualViewState();
}

class _DP1ResponseVisualViewState extends State<DP1ResponseVisualView> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordBloc, RecordState>(
      listener: (context, state) {},
      buildWhen: (previous, current) {
        return (current is RecordSuccessState) || current is RecordInitialState;
      },
      builder: (context, state) {
        if (state is RecordSuccessState) {
          final playlist = state.lastDP1Call!;
          if (playlist.items.isNotEmpty) {
            return PlaylistAssetGridView(
              playlist: playlist,
              key: Key(playlist.id),
              header: playlist.title.isEmpty
                  ? SizedBox()
                  : PlaylistItem(
                      playlist: playlist,
                      dividerColor: AppColor.auGreyBackground,
                    ),
              backgroundColor: AppColor.primaryBlack,
            );
          }
        }
        return const SizedBox();
      },
    );
  }
}
