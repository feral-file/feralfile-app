import 'package:autonomy_flutter/design/build/components/Header.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/widgets/buttons/back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.backTitle,
    this.centeredTitle,
    this.onPlayTap,
    this.backgroundColor,
    this.actions = const [],
  });

  final String? backTitle;
  final String? centeredTitle;
  final VoidCallback? onPlayTap;
  final Color? backgroundColor;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final appBar = SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: HeaderTokens.paddingHorizontal.toDouble(),
              vertical: HeaderTokens.paddingVertical.toDouble(),
            ),
            color: backgroundColor ?? Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: CustomBackButton(
                    onTap: () => Navigator.pop(context),
                    title: backTitle ?? 'Index',
                  ),
                ),
                if (centeredTitle != null)
                  Center(
                    child: Text(
                      centeredTitle!,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (actions.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      children: actions
                          .map(
                            (e) => Row(
                              children: [
                                e,
                                const SizedBox(height: 10),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        );

        final systemUiOverlayStyle = SystemUiOverlayStyle(
          statusBarColor: backgroundColor ?? PrimitivesTokens.colorsDarkGrey,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemUiOverlayStyle,
          child: appBar,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(69);
}
