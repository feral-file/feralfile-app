import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/components/PlaylistListItem.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sentry/sentry.dart';

/// Playlist List Item - Displays playlist info with primary and secondary text
class PlaylistTitle extends StatefulWidget {
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    required this.collectionState,
    this.onTap,
    this.onRetry,
    this.total,
    this.channelReference,
    this.options = const [],
    this.showDivider = false,
    this.padding,
    this.channelVisible = true,
    this.isFromPlaylistsPage = false,
    this.playlistReference,
    super.key,
  });

  final String primaryText;
  final UserAllOwnCollectionState? collectionState;
  final String secondaryText;
  final int? total;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final ChannelReference? channelReference;
  final List<OptionItem> options;
  final bool showDivider;
  final EdgeInsets? padding;
  final bool channelVisible;
  final bool isFromPlaylistsPage;
  final PlaylistReference? playlistReference;

  @override
  State<PlaylistTitle> createState() => _PlaylistTitleState();
}

class _PlaylistTitleState extends State<PlaylistTitle> {
  @override
  void initState() {
    super.initState();
    _sendSentryWhenCachedTotalIsGreaterThanDiscoveredTotal();
  }

  @override
  Widget build(BuildContext context) {
    final statusWidget = _buildStatus(context);
    final effectivePadding = widget.padding ??
        EdgeInsets.symmetric(
          horizontal: widget.showDivider
              ? ResponsiveLayout.paddingHorizontal
              : PlaylistListItemTokens.paddingHorizontal,
          vertical:
              widget.showDivider ? 16 : PlaylistListItemTokens.paddingVertical,
        );

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            Container(
              padding: effectivePadding,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title row - for detail page: title, for list: title + secondary text
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.primaryText,
                                style: AppTypography.body(context).white,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!widget.showDivider) ...[
                              SizedBox(width: LayoutConstants.space2),
                              Text(
                                widget.secondaryText,
                                style: AppTypography.body(context).italic.grey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        // Channel reference
                        if (widget.channelReference != null &&
                            widget.channelVisible) ...[
                          SizedBox(height: LayoutConstants.space1),
                          GestureDetector(
                            onTap: () {
                              if (widget.playlistReference != null) {
                                injector<NavigationService>().navigateTo(
                                  AppRouter.channelDetailPage,
                                  arguments: ChannelDetailPagePayload(
                                    channelReference: widget.channelReference!,
                                    backTitle: widget.isFromPlaylistsPage
                                        ? 'Playlists'
                                        : widget.primaryText,
                                  ),
                                );
                              }
                            },
                            child: Text(
                              widget.channelReference!.channel.title,
                              style: AppTypography.body(context).grey,
                            ),
                          ),
                        ],
                        // Status widget
                        if (statusWidget != null) ...[
                          SizedBox(height: LayoutConstants.space1),
                          statusWidget
                        ],
                      ],
                    ),
                  ),
                  // Options menu button
                  if (widget.options.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async => _showPlaylistOptionsDialog(
                        context,
                        widget.playlistReference,
                      ),
                      constraints: const BoxConstraints(
                        maxWidth: 44,
                        maxHeight: 44,
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: SvgPicture.asset(
                        'assets/images/more_circle.svg',
                      ),
                    )
                ],
              ),
            ),
            // Divider
            if (widget.showDivider)
              Divider(
                height: 1,
                color: AppColor.primaryBlack,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSentryWhenCachedTotalIsGreaterThanDiscoveredTotal() async {
    final addressState = widget.collectionState?.addressStates.first;
    if (addressState == null) return;

    final totalTokensIndexed = addressState.indexingStatus?.totalTokensIndexed;
    final totalTokensViewable =
        addressState.indexingStatus?.totalTokensViewable;
    if (widget.total != null &&
        (totalTokensIndexed != null && widget.total! > totalTokensIndexed ||
            totalTokensViewable != null &&
                widget.total! > totalTokensViewable)) {
      final cachedToken =
          await injector<IndexerDatabaseAbstract>().getTokensByOwners(
        owners: [addressState.address],
      );
      final cachedCids = cachedToken.map((e) => e.cid).toList();
      log.info('cachedCids: $cachedCids');
      log.info('totalTokensIndexed: $totalTokensIndexed');
      log.info('totalTokensViewable: $totalTokensViewable');
      log.info('total: ${widget.total}');
      log.info('addressState.address: ${addressState.address}');

      final indexerToken = await injector<NftTokensService>().fetchManualTokens(
        cids: cachedCids,
      );
      final missingCids = cachedToken
          .where((e) => !indexerToken.any((t) => t.cid == e.cid))
          .map((e) => e.cid)
          .toList();
      log.info('missingCids: $missingCids');
      await Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Cached total is greater than discovered total'),
        extra: {
          'cachedTotal': widget.total,
          'totalTokensIndexed': totalTokensIndexed,
          'totalTokensViewable': totalTokensViewable,
          'missingCids': missingCids.join(','),
          'cachedCids': cachedCids.join(','),
        },
        debugMeta: DebugMeta(unknown: {
          'cachedTotal': widget.total,
          'totalTokensIndexed': totalTokensIndexed,
          'totalTokensViewable': totalTokensViewable,
          'missingCids': missingCids.join(','),
          'cachedCids': cachedCids.join(','),
        }),
      ));
    }
  }

  Future<void> _showPlaylistOptionsDialog(
    BuildContext context,
    PlaylistReference? playlistReference,
  ) async {
    if (playlistReference == null) return;
    await UIHelper.showDrawerAction(
      context,
      options: [
        ...widget.options,
        OptionItem.emptyOptionItem,
      ],
    );
  }

  Widget? _buildStatus(BuildContext context) {
    if (widget.collectionState == null ||
        widget.collectionState!.addressStates.isEmpty) {
      return null;
    }

    // Lấy AddressState đầu tiên
    final addressState = widget.collectionState!.addressStates.first;
    final indexingStatus = addressState.indexingStatus;

    final cachedTotal = widget.total; // ?? addressState.assetTokens.length;
    final discoveredTotal = indexingStatus?.totalTokensIndexed;
    final readyTotal = indexingStatus?.totalTokensViewable;

    String? statusText;
    bool showRetry = false;

    // Check AddressStateType first (error states have highest priority)
    switch (addressState.state) {
      // Initial state - show syncing
      case AddressStateType.init:
      case AddressStateType.fetchingArtworks:
      case AddressStateType.fetchingArtworksFailed:
      case AddressStateType.indexStated:
      case AddressStateType.indexingDone:
      case AddressStateType.indexingIncomplete:
      case AddressStateType.getStatusFailed:
      case AddressStateType.fetchingArtworksDone:
        // If indexingStatus is available, use IndexingJobStatus
        if (indexingStatus != null) {
          switch (indexingStatus.status) {
            case IndexingJobStatus.running:
              final parts = <String>['Syncing'];
              parts.add('$cachedTotal ready');
              if (discoveredTotal != null) {
                parts.add('$discoveredTotal found');
              }
              statusText = parts.join(' • ');
              break;
            case IndexingJobStatus.paused:
              final parts = <String>['Paused'];
              parts.add('$cachedTotal ready');
              parts.add('resumes later');
              statusText = parts.join(' • ');
              break;
            case IndexingJobStatus.completed:
              if (addressState.state == AddressStateType.fetchingArtworksDone) {
                final parts = <String>['Up to date'];
                if (readyTotal != null) {
                  parts.add('$readyTotal works');
                }
                statusText = parts.join(' • ');
                break;
              } else {
                final parts = <String>['Syncing'];
                if (cachedTotal != null) {
                  parts.add('$cachedTotal ready');
                }
                if (discoveredTotal != null) {
                  parts.add('$discoveredTotal found');
                }
                statusText = parts.join(' • ');
                break;
              }
            case IndexingJobStatus.failed:
            case IndexingJobStatus.canceled:
              statusText = 'Sync issue';
              showRetry = true;
              break;
          }
        } else {
          // Fallback to AddressStateType when no indexingStatus

          final parts = <String>['Syncing'];
          if (cachedTotal != null) {
            parts.add('$cachedTotal ready');
          }
          if (discoveredTotal != null) {
            parts.add('$discoveredTotal found');
          }
          statusText = parts.join(' • ');
        }
        break;
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
              if (widget.onRetry != null) {
                widget.onRetry!();
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
