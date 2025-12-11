import 'package:autonomy_flutter/design/build/components/Header.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/widgets/buttons/back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({
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

class SetupAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SetupAppBar({
    super.key,
    this.title = '',
    this.titleStyle,
    this.actions = const [],
    this.onBack,
    this.backgroundColor = PrimitivesTokens.colorsDarkGrey,
    this.titleColor = PrimitivesTokens.colorsWhite,
    this.statusBarColor,
    this.surfaceTintColor,
    this.withDivider = true,
    this.isDarkMode = true,
  });

  final String title;
  final TextStyle? titleStyle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final Color titleColor;
  final Color? statusBarColor;
  final Color? surfaceTintColor;
  final bool withDivider;
  final bool isDarkMode;

  Widget backButton(
    BuildContext context, {
    required VoidCallback onBack,
    Color? color,
  }) =>
      Semantics(
        label: 'Back Button',
        child: IconButton(
          constraints: const BoxConstraints(
            maxWidth: 44,
            maxHeight: 44,
            minWidth: 44,
            minHeight: 44,
          ),
          onPressed: onBack,
          icon: Padding(
            padding: const EdgeInsets.all(10),
            child: SvgPicture.asset(
              'assets/images/icon_back.svg',
              width: 24,
              height: 24,
              colorFilter: color != null
                  ? ColorFilter.mode(color, BlendMode.srcIn)
                  : null,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? backgroundColor,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
      centerTitle: true,
      scrolledUnderElevation: 0,
      toolbarHeight: 54,
      leading: backButton(
        context,
        onBack: () {
          if (onBack != null) {
            onBack!();
          } else {
            Navigator.pop(context);
          }
        },
        color: titleColor,
      ),
      leadingWidth: 56,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: titleStyle ?? theme.textTheme.small,
        textAlign: TextAlign.center,
      ),
      actions: [
        ...actions ?? [],
      ],
      backgroundColor: backgroundColor,
      surfaceTintColor: surfaceTintColor ?? Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      bottom: withDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: addOnlyDivider(
                color: PrimitivesTokens.colorsBlack,
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
