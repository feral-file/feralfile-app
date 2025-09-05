import 'dart:async';

import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_details_bloc.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_details_state.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_exhibitions_page.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_posts_page.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_works_page.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/feralfile_home/artwork_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_exhibition_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_post_view.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/url_hepler.dart';
import 'package:autonomy_flutter/view/alumni_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:url_launcher/url_launcher.dart';

class AlumniDetailsPagePayload {
  final String alumniID;

  AlumniDetailsPagePayload({required this.alumniID});
}

class AlumniDetailsPage extends StatefulWidget {
  final AlumniDetailsPagePayload payload;

  const AlumniDetailsPage({required this.payload, super.key});

  @override
  State<AlumniDetailsPage> createState() => _AlumniDetailsPageState();
}

class _AlumniDetailsPageState extends State<AlumniDetailsPage> {
  @override
  void initState() {
    super.initState();
    context
        .read<AlumniDetailsBloc>()
        .add(AlumniDetailsFetchAlumniEvent(alumniID: widget.payload.alumniID));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getFFAppBar(
          context,
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: Colors.black,
        body: BlocConsumer<AlumniDetailsBloc, AlumniDetailsState>(
            listener: (context, state) {},
            builder: (BuildContext context, AlumniDetailsState state) {
              final alumni = state.alumni;
              if (alumni == null) {
                return _loading();
              }
              return _content(context, state);
            }),
      );

  Widget _loading() => const Center(
        child: LoadingWidget(),
      );

  Widget _avatar(BuildContext context, AlumniAccount alumni) {
    final avatarUrl = alumni.avatarUrl;
    return AspectRatio(
      aspectRatio: 1,
      child: AlumniAvatar(url: avatarUrl),
    );
  }

  Widget _content(BuildContext context, AlumniDetailsState state) {
    final user = state.alumni!;
    final series = state.series;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _userProfile(context, user),
        )),
        if ((series?.length ?? 0) > 0)
          ..._workSection(
            context,
            user,
            series ?? [],
            state.userCollections,
          ),
        if ((state.exhibitions?.length ?? 0) > 0) ...[
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
            ),
          ),
          ..._exhibitionSection(context, user, state.exhibitions ?? []),
        ],
        if ((state.posts?.length ?? 0) > 0) ...[
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
            ),
          ),
          ..._postSection(context, user, state.posts ?? []),
        ],
      ],
    );
  }

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

  String _userRole(AlumniAccount alumni) {
    if (alumni.isArtist == true && alumni.isCurator == true) {
      return 'artist_curator'.tr();
    } else if (alumni.isArtist == true) {
      return 'artist'.tr();
    } else if (alumni.isCurator == true) {
      return 'curator'.tr();
    }
    return '';
  }

  Widget _userProfile(BuildContext context, AlumniAccount alumni) {
    final theme = Theme.of(context);
    final subTitleStyle = theme.textTheme.ppMori400White12
        .copyWith(color: AppColor.auQuickSilver);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _avatar(context, alumni),
            ),
          ],
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          _userRole(alumni),
          style: subTitleStyle,
        ),
        const SizedBox(
          height: 36,
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
          _alumniUrl(context, alumni.instagramUrl!, title: 'instagram'.tr()),
          const SizedBox(
            height: 12,
          ),
        ],

        if (alumni.twitterUrl != null && alumni.twitterUrl!.isNotEmpty) ...[
          _alumniUrl(context, alumni.twitterUrl!, title: 'twitter'.tr()),
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

  Widget _header(BuildContext context,
      {required String title, String? subtitle}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.ppMori700White24.copyWith(fontSize: 36),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(
              width: 8,
            ),
            Text(
              subtitle,
              style: theme.textTheme.ppMori400White24
                  .copyWith(fontSize: 36, color: AppColor.auQuickSilver),
            ),
          ]
        ],
      ),
    );
  }

  void _gotoAlumniWorksPage(BuildContext context, AlumniAccount alumni) {
    unawaited(Navigator.of(context).pushNamed(
      AppRouter.alumniWorksPage,
      arguments: AlumniWorksPagePayload(alumni),
    ));
  }

  List<Widget> _workSection(BuildContext context, AlumniAccount alumni,
      List<FFSeries> series, List<UserCollection> userCollections) {
    final listSeriesAndColections =
        series.mergeIndexerCollection(userCollections);
    final header = _header(context,
        title: 'works'.tr(), subtitle: '${listSeriesAndColections.length}');
    final viewAll = PrimaryAsyncButton(
      color: AppColor.white,
      onTap: () {
        _gotoAlumniWorksPage(context, alumni);
      },
      text: 'view_all_works'.tr(),
    );
    const viewAllBreakpoint = 4;

    return [
      SliverToBoxAdapter(child: header),
      SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: SeriesView(
                series: series,
                userCollections: userCollections,
                limit: viewAllBreakpoint,
                isScrollable: false,
                artist: alumni,
              ),
            ),
          ],
        ),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(
          height: 36,
        ),
      ),
      SliverToBoxAdapter(
        child: listSeriesAndColections.length > viewAllBreakpoint
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: viewAll,
              )
            : const SizedBox(),
      ),
      const SliverToBoxAdapter(
          child: SizedBox(
        height: 40,
      ))
    ];
  }

  void _viewAllAlumniExhibitions(BuildContext context, AlumniAccount alumni) {
    unawaited(Navigator.of(context).pushNamed(
      AppRouter.alumniExhibitionsPage,
      arguments: AlumniExhibitionsPagePayload(alumni),
    ));
  }

  List<Widget> _exhibitionSection(BuildContext context, AlumniAccount alumni,
      List<Exhibition> exhibitions) {
    final header = _header(context,
        title: 'exhibitions'.tr(), subtitle: '${exhibitions.length}');
    final viewAll = PrimaryAsyncButton(
      onTap: () {
        _viewAllAlumniExhibitions(context, alumni);
      },
      color: AppColor.white,
      text: 'view_all_exhibitions'.tr(),
    );
    const viewAllBreakpoint = 2;
    return [
      SliverToBoxAdapter(child: header),
      SliverToBoxAdapter(
          child: addDivider(
              height: 36, color: AppColor.auQuickSilver, thickness: 0.5)),
      SliverToBoxAdapter(
          child: Row(
        children: [
          Expanded(
            child: ListExhibitionView(
              exhibitions: exhibitions.length > viewAllBreakpoint
                  ? exhibitions.sublist(0, viewAllBreakpoint)
                  : exhibitions,
              isScrollable: false,
            ),
          ),
        ],
      )),
      SliverToBoxAdapter(
          child: addDivider(
              height: 36, color: AppColor.auQuickSilver, thickness: 0.5)),
      const SliverToBoxAdapter(
        child: SizedBox(
          height: 36,
        ),
      ),
      SliverToBoxAdapter(
        child: exhibitions.length > viewAllBreakpoint
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: viewAll,
              )
            : const SizedBox(),
      )
    ];
  }

  void _viewAllAlumniPosts(BuildContext context, AlumniAccount alumni) {
    unawaited(Navigator.of(context).pushNamed(
      AppRouter.alumniPostPage,
      arguments: AlumniPostsPagePayload(alumni),
    ));
  }

  List<Widget> _postSection(
      BuildContext context, AlumniAccount alumni, List<Post> posts) {
    final header = _header(context,
        title: 'publications'.tr(), subtitle: '${posts.length}');
    final viewAll = PrimaryAsyncButton(
      onTap: () {
        _viewAllAlumniPosts(context, alumni);
      },
      color: AppColor.white,
      text: 'view_all_posts'.tr(),
    );
    const viewAllBreakpoint = 2;

    return [
      SliverToBoxAdapter(child: header),
      SliverToBoxAdapter(
          child: addDivider(
              height: 36, color: AppColor.auQuickSilver, thickness: 0.5)),
      SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: ListPostView(
                posts: posts.length > viewAllBreakpoint
                    ? posts.sublist(0, viewAllBreakpoint)
                    : posts,
                isScrollable: false,
              ),
            ),
          ],
        ),
      ),
      SliverToBoxAdapter(
        child: addDivider(
            height: 36, color: AppColor.auQuickSilver, thickness: 0.5),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(
          height: 36,
        ),
      ),
      SliverToBoxAdapter(
        child: posts.length > viewAllBreakpoint
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: viewAll,
              )
            : const SizedBox(),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(
          height: 36,
        ),
      ),
    ];
  }
}

class ReadMoreText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle style;

  const ReadMoreText(
      {required this.text, required this.style, this.maxLines = 3, super.key});

  @override
  State<ReadMoreText> createState() => _ReadMoreTextState();
}

class _ReadMoreTextState extends State<ReadMoreText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Column(
          children: [
            HtmlWidget(
              widget.text,
              customStylesBuilder: auHtmlStyle,
              textStyle: widget.style,
              onTapUrl: (url) async {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
                return true;
              },
            ),
            // if (!_isExpanded) ...[
            //   const SizedBox(
            //     height: 16,
            //   ),
            //   Text(
            //     'read_more'.tr(),
            //     style: widget.style.copyWith(
            //       color: AppColor.auQuickSilver,
            //     ),
            //   ),
            // ]
          ],
        ),
      );
}
