import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/view/now_displaying/custom_now_displaying_view.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
import 'package:flutter/material.dart';

class NowDisplayingStatusView extends StatelessWidget {
  const NowDisplayingStatusView({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    return CustomNowDisplayingView(
      builder: (context) {
        return Container(
          constraints:  BoxConstraints(
            maxHeight: kNowDisplayingHeight,
            minHeight: kNowDisplayingHeight,
          ),
          child: Column(
            children: [
              Text(
                status,
                style: Theme.of(context).textTheme.ppMori400Black14,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
      customAction: [
        ValueListenableBuilder(
          valueListenable: CustomRouteObserver.currentRoute,
          builder: (context, route, child) {
            if (route?.isRecordScreenShowing ?? false) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              child: Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  color: AppColor.feralFileLightBlue,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onTap: () {
                injector<NavigationService>().popToRouteOrPush(
                  AppRouter.voiceCommandPage,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
