import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:flutter/material.dart';

class ChannelHeader extends StatelessWidget {
  const ChannelHeader({
    required this.channelReference,
    this.clickable = true,
    this.maxLines,
    super.key,
  });

  final ChannelReference channelReference;
  final bool clickable;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        if (!clickable) return;
        Navigator.of(context).pushNamed(
          AppRouter.channelDetailPage,
          arguments:
              ChannelDetailPagePayload(channelReference: channelReference),
        );
      },
      child: Container(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelReference.channel.title,
                    style: AppTypography.body(context).white,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    channelReference.channel.summary ?? '',
                    maxLines: maxLines,
                    overflow: maxLines != null
                        ? TextOverflow.ellipsis
                        : TextOverflow.visible,
                    style: AppTypography.body(context).grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
