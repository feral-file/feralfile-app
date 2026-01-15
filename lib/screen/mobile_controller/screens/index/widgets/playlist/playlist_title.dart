import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/components/PlaylistListItem.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:flutter/material.dart';

/// Playlist List Item - Displays playlist info with primary and secondary text
class PlaylistTitle extends StatelessWidget {
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    this.collectionState,
    this.onTap,
    this.total,
    super.key,
  });

  final String primaryText;
  final UserAllOwnCollectionState? collectionState;
  final String secondaryText;
  final int? total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: PlaylistListItemTokens.paddingHorizontal,
          vertical: PlaylistListItemTokens.paddingVertical,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          primaryText,
                          style: AppTypography.body(context).white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (total != null) ...[
                          SizedBox(width: LayoutConstants.space1),
                          Text(
                            '($total)',
                            style: AppTypography.bodySmall(context).grey.italic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (_buildStatusText() != null) ...[
                          SizedBox(width: LayoutConstants.space2),
                          Text(
                            _buildStatusText()!,
                            style: AppTypography.bodySmall(context).grey.italic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: LayoutConstants.space2),
                  Text(
                    secondaryText,
                    style: AppTypography.body(context).italic.grey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _buildStatusText() {
    if (collectionState == null || collectionState!.addressStates.isEmpty) {
      return null;
    }

    // Lấy AddressState đầu tiên
    final addressState = collectionState!.addressStates.first;
    final indexingStatus = addressState.indexingStatus;

    final readyCount =
        indexingStatus?.tokensProcessed ?? addressState.assetTokens.length;
    final discoveredTotal = indexingStatus?.tokensProcessed ?? 0;

    // Check indexing status first
    if (indexingStatus != null) {
      switch (indexingStatus.status) {
        case IndexingJobStatus.running:
          return 'Syncing • $readyCount ready • $discoveredTotal found';
        case IndexingJobStatus.paused:
          return 'Paused • $readyCount ready • resumes later';
        case IndexingJobStatus.completed:
          return 'Up to date • $discoveredTotal works';
        case IndexingJobStatus.failed:
        case IndexingJobStatus.canceled:
          return 'Sync issue • Tap to retry.';
      }
    }

    // Fallback to AddressStateType
    switch (addressState.state) {
      case AddressStateType.fetchingArtworksDone:
        return 'Up to date • $discoveredTotal works';
      case AddressStateType.fetchingArtworksFailed:
        return 'Sync issue • Tap to retry.';
      case AddressStateType.indexStated:
      case AddressStateType.fetchingArtworks:
        return 'Syncing • $readyCount ready • $discoveredTotal found';
      default:
        return null;
    }
  }
}
