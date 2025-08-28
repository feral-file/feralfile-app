import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

class ExhibitionNoteView extends StatelessWidget {
  const ExhibitionNoteView({required this.exhibition, this.width, super.key});

  final Exhibition exhibition;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColor.auGreyBackground,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exhibition.isJohnGerrardShow
                  ? 'artist_note'.tr()
                  : 'curators_note'.tr(),
              style: theme.textTheme.ppMori400White12,
            ),
            const SizedBox(height: 30),
            if (exhibition.noteTitle?.isNotEmpty == true) ...[
              Text(
                exhibition.noteTitle!,
                style: theme.textTheme.ppMori700White14,
              ),
              const SizedBox(height: 20),
            ],
            if (exhibition.noteBrief?.isNotEmpty == true) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: HtmlWidget(
                  customStylesBuilder: auHtmlStyle,
                  exhibition.noteBrief!,
                  textStyle: theme.textTheme.ppMori400White14,
                  onTapUrl: (url) async {
                    await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                    return true;
                  },
                ),
              ),
              if (exhibition.noteBrief != exhibition.note) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    await injector<NavigationService>()
                        .openFeralFileExhibitionNotePage(exhibition.slug);
                  },
                  child: Text(
                    'read_more'.tr(),
                    style: theme.textTheme.ppMori400White14.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: AppColor.white,
                    ),
                  ),
                ),
              ]
            ],
          ],
        ),
      ),
    );
  }
}
