import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _myCollectionButton(context),
        Expanded(
          child: Center(
            child: Text(
              'Collection page',
              style: theme.textTheme.ppMori400White12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _myCollectionButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Handle navigation to My Collection
        Navigator.of(context).pushNamed(
          AppRouter.oldHomePage,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.primaryBlack,
          borderRadius: BorderRadius.circular(90),
        ),
        padding: ResponsiveLayout.paddingAll,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Collection',
              style: Theme.of(context).textTheme.ppMori400White12,
            ),
            const SizedBox(width: 20),
            SvgPicture.asset(
              'assets/images/arraw-left.svg',
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
