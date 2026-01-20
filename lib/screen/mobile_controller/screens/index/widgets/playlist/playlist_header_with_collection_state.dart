import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_title.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Widget that wraps PlaylistTitle and manages UserAllOwnCollectionBloc lifecycle.
///
/// This widget properly manages the bloc lifecycle by:
/// - Getting or creating the bloc in initState
/// - Releasing the bloc in dispose
/// - Handling owners changes in didUpdateWidget
///
/// Use this widget instead of directly calling getOrCreateBloc in builders.
class PlaylistHeaderWithCollectionState extends StatefulWidget {
  const PlaylistHeaderWithCollectionState({
    required this.primaryText,
    required this.secondaryText,
    required this.owners,
    required this.total,
    this.onTap,
    super.key,
  });

  final String primaryText;
  final String secondaryText;
  final List<String> owners;
  final int? total;
  final VoidCallback? onTap;

  @override
  State<PlaylistHeaderWithCollectionState> createState() =>
      _PlaylistHeaderWithCollectionStateState();
}

class _PlaylistHeaderWithCollectionStateState
    extends State<PlaylistHeaderWithCollectionState> {
  UserAllOwnCollectionBloc? _bloc;

  @override
  void initState() {
    super.initState();
    if (widget.owners.isNotEmpty) {
      final manager = injector<UserAllOwnCollectionBlocManager>();
      _bloc = manager.getOrCreateBloc(widget.owners);
    }
  }

  @override
  void didUpdateWidget(PlaylistHeaderWithCollectionState oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if owners changed
    if (!widget.owners.isEqual(oldWidget.owners)) {
      // Release old bloc if exists
      if (_bloc != null) {
        injector<UserAllOwnCollectionBlocManager>()
            .releaseBlocByInstance(_bloc!);
        _bloc = null;
      }
      // Get or create new bloc if owners are not empty
      if (widget.owners.isNotEmpty) {
        final manager = injector<UserAllOwnCollectionBlocManager>();
        _bloc = manager.getOrCreateBloc(widget.owners);
      }
    }
  }

  @override
  void dispose() {
    if (_bloc != null) {
      injector<UserAllOwnCollectionBlocManager>().releaseBlocByInstance(_bloc!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If owners are empty, show PlaylistTitle without collection state
    if (widget.owners.isEmpty || _bloc == null) {
      return PlaylistTitle(
        primaryText: widget.primaryText,
        secondaryText: widget.secondaryText,
        collectionState: null,
        total: widget.total,
        onTap: widget.onTap,
        channelVisible: false,
      );
    }

    return BlocBuilder<UserAllOwnCollectionBloc, UserAllOwnCollectionState>(
      bloc: _bloc!,
      builder: (context, collectionState) {
        final addressState = collectionState.addressStates.isNotEmpty
            ? collectionState.addressStates.first
            : null;
        final isError =
            addressState?.indexingStatus?.status == IndexingJobStatus.failed ||
                addressState?.indexingStatus?.status ==
                    IndexingJobStatus.canceled ||
                addressState?.state == AddressStateType.fetchingArtworksFailed;

        return PlaylistTitle(
          primaryText: widget.primaryText,
          secondaryText: widget.secondaryText,
          collectionState: collectionState,
          total: widget.total,
          onTap: isError
              ? () {
                  _bloc!.add(Reindex());
                }
              : widget.onTap,
          onRetry: () {
            _bloc!.add(Reindex());
          },
        );
      },
    );
  }
}
