import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DetailPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailPageAppBar(
      {super.key,
      required this.title,
      this.actions = const [],
      this.statusBarColor});

  final String title;
  final List<Widget> actions;
  final Color? statusBarColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context) {
    final appBar = Container(
      color: AppColor.auGreyBackground,
      padding: const EdgeInsets.all(10),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: _backIcon(context, title)),
            const SizedBox(width: 10),
            ...actions.map(
              (e) => Row(
                children: [
                  e,
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor ?? AppColor.auGreyBackground,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: appBar,
    );
  }

  Widget _backIcon(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: AppColor.auLightGrey),
              borderRadius: BorderRadius.circular(90),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/arrow-left.svg',
                  width: 15,
                  height: 12,
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.ppMori400Grey12,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
