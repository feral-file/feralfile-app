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
    required this.collectionState,
    this.onTap,
    this.onRetry,
    this.total,
    super.key,
  });

  final String primaryText;
  final UserAllOwnCollectionState? collectionState;
  final String secondaryText;
  final int? total;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final statusWidget = _buildStatus(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: PlaylistListItemTokens.paddingHorizontal,
          vertical: PlaylistListItemTokens.paddingVertical,
        ),
        child: Column(
          children: [
            Row(
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
                            Expanded(
                              child: Text(
                                primaryText,
                                style: AppTypography.body(context).white,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
            if (statusWidget != null) ...[
              SizedBox(height: LayoutConstants.space1),
              statusWidget
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildStatus(BuildContext context) {
    if (collectionState == null || collectionState!.addressStates.isEmpty) {
      return null;
    }

    // Lấy AddressState đầu tiên
    final addressState = collectionState!.addressStates.first;
    final indexingStatus = addressState.indexingStatus;

    final readyCount = total; // ?? addressState.assetTokens.length;
    final discoveredTotal = indexingStatus?.totalTokensIndexed;

    String? statusText;
    bool showRetry = false;

    // Check AddressStateType first (error states have highest priority)
    switch (addressState.state) {
      // Initial state - show syncing
      case AddressStateType.init:
        statusText = 'Syncing';
        break;

      // Error states - always show error regardless of IndexingJobStatus
      case AddressStateType.indexingIncomplete:
      case AddressStateType.getStatusFailed:
      case AddressStateType.fetchingArtworksFailed:
        statusText = 'Sync issue';
        showRetry = true;
        break;

      // Non-error states - use IndexingJobStatus if available
      case AddressStateType.indexStated:
      case AddressStateType.indexingDone:
      case AddressStateType.fetchingArtworks:
      case AddressStateType.fetchingArtworksDone:
        // If indexingStatus is available, use IndexingJobStatus
        if (indexingStatus != null) {
          switch (indexingStatus.status) {
            case IndexingJobStatus.running:
              final parts = <String>['Syncing'];
              parts.add('$readyCount ready');
              if (discoveredTotal != null) {
                parts.add('$discoveredTotal found');
              }
              statusText = parts.join(' • ');
              break;
            case IndexingJobStatus.paused:
              final parts = <String>['Paused'];
              parts.add('$readyCount ready');
              parts.add('resumes later');
              statusText = parts.join(' • ');
              break;
            case IndexingJobStatus.completed:
              if (discoveredTotal != null) {
                statusText = 'Up to date • $discoveredTotal works';
              } else {
                statusText = 'Up to date';
              }
              break;
            case IndexingJobStatus.failed:
            case IndexingJobStatus.canceled:
              statusText = 'Sync issue';
              showRetry = true;
              break;
          }
        } else {
          // Fallback to AddressStateType when no indexingStatus
          switch (addressState.state) {
            case AddressStateType.indexStated:
            case AddressStateType.fetchingArtworks:
              final parts = <String>['Syncing'];
              parts.add('$readyCount ready');
              if (discoveredTotal != null) {
                parts.add('$discoveredTotal found');
              }
              statusText = parts.join(' • ');
              break;
            case AddressStateType.indexingDone:
            case AddressStateType.fetchingArtworksDone:
              if (discoveredTotal != null) {
                statusText = 'Up to date • $discoveredTotal works';
              } else {
                statusText = 'Up to date';
              }
              break;
            default:
              statusText = null;
              break;
          }
        }
        break;
    }

    if (statusText == null) {
      return null;
    }

    return Row(
      children: [
        Text(
          statusText,
          style: AppTypography.bodySmall(context).grey.italic,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showRetry) ...[
          Text(
            ' • ',
            style: AppTypography.bodySmall(context).grey.italic,
          ),
          GestureDetector(
            onTap: () {
              if (onRetry != null) {
                onRetry!();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  Text(
                    'Tap to retry',
                    style:
                        AppTypography.bodySmall(context).grey.italic.underline,
                    maxLines: 1,
                  ),
                  // Icon(
                  //   Icons.refresh,
                  //   size: LayoutConstants.iconSizeSmall,
                  //   color: AppColor.auQuickSilver,
                  // ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
