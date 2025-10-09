import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/channel_detail.page.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';

class ChannelItem extends StatelessWidget {
  const ChannelItem({
    required this.channelReference,
    this.clickable = true,
    super.key,
  });

  final ChannelReference channelReference;
  final bool clickable;

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
                horizontal: ResponsiveLayout.paddingHorizontal,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelReference.channel.title,
                    style: theme.textTheme.ppMori400White12,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    channelReference.channel.summary ?? '',
                    style: theme.textTheme.ppMori400Grey12,
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              color: AppColor.primaryBlack,
            ),
          ],
        ),
      ),
    );
  }
}
