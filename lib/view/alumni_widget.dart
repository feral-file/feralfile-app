import 'dart:async';

import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_details_page.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/url_hepler.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';

class AlumniAvatar extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;

  const AlumniAvatar({
    required this.url,
    this.width,
    this.height,
    super.key,
  });

  Widget _avatar(BuildContext context) {
    final avatarUrl = url;
    return avatarUrl != null
        ? FFCacheNetworkImage(
            imageUrl: avatarUrl,
            fit: BoxFit.fill,
            placeholder: (context, url) => Container(
              height: height,
              width: width,
              color: Colors.transparent,
              child: Center(
                child: loadingIndicatorLight(),
              ),
            ),
          )
        : AspectRatio(
            aspectRatio: 1,
            child: SvgPicture.asset('assets/images/default_avatar.svg'),
          );
  }

  @override
  Widget build(BuildContext context) => _avatar(context);
}

class AlumniProfile extends StatelessWidget {
  final AlumniAccount alumni;
  final bool isShowAlumniRole;

  const AlumniProfile({
    required this.alumni,
    super.key,
    this.isShowAlumniRole = true,
  });

  String _alumniRole(AlumniAccount alumni) {
    if (alumni.isArtist == true && alumni.isCurator == true) {
      return 'artist_curator'.tr();
    } else if (alumni.isArtist == true) {
      return 'artist'.tr();
    } else if (alumni.isCurator == true) {
      return 'curator'.tr();
    }
    return '';
  }

  Widget _alumniProfile(BuildContext context, AlumniAccount alumni) {
    final theme = Theme.of(context);
    final subTitleStyle = theme.textTheme.ppMori400White12
        .copyWith(color: AppColor.auQuickSilver);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: AlumniAvatar(url: alumni.avatarUrl),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 8,
        ),
        if (isShowAlumniRole) ...[
          Text(
            _alumniRole(alumni),
            style: subTitleStyle,
          ),
        ],
        const SizedBox(
          height: 64,
        ),
        Text(
          alumni.displayAlias,
          style: theme.textTheme.ppMori700White24.copyWith(fontSize: 36),
        ),
        const SizedBox(
          height: 24,
        ),
        if (alumni.location != null) ...[
          Text(
            alumni.location!,
            style: subTitleStyle.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(
            height: 24,
          ),
        ],
        if (alumni.websiteUrl.isNotEmpty)
          ...alumni.websiteUrl
              .map((url) => [
                    _alumniUrl(context, url),
                    const SizedBox(
                      height: 12,
                    )
                  ])
              .expand((element) => element),
        if (alumni.instagramUrl != null && alumni.instagramUrl!.isNotEmpty) ...[
          _alumniUrl(context, alumni.instagramUrl!, title: 'Instagram'),
          const SizedBox(
            height: 12,
          ),
        ],

        if (alumni.twitterUrl != null && alumni.twitterUrl!.isNotEmpty) ...[
          _alumniUrl(context, alumni.twitterUrl!, title: 'Twitter'),
          const SizedBox(
            height: 12,
          ),
        ],
        const SizedBox(
          height: 32,
        ),
        if (alumni.bio != null) ...[
          ReadMoreText(
            text: alumni.bio!,
            style: theme.textTheme.ppMori400White14,
          ),
          const SizedBox(
            height: 16,
          ),
        ],
        // Add more widgets here
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _alumniProfile(context, alumni);

  Widget _alumniUrl(BuildContext context, String url, {String? title}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        unawaited(launchUrl(Uri.parse(url)));
      },
      child: Row(
        children: [
          Text(
            title ?? UrlHepler.shortenUrl(url),
            style: theme.textTheme.ppMori400White12
                .copyWith(color: AppColor.auQuickSilver),
          ),
          const SizedBox(
            width: 8,
          ),
          SvgPicture.asset(
            'assets/images/arrow_45.svg',
            width: 12,
            height: 12,
            colorFilter:
                const ColorFilter.mode(AppColor.auQuickSilver, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}
