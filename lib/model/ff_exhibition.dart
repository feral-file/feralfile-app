import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:easy_localization/easy_localization.dart';

class Exhibition {
  final String id;
  final String title;
  final String slug;
  final DateTime exhibitionStartAt;
  final int? previewDuration;

  final String? noteTitle;
  final String? noteBrief;
  final String? note;

  final String coverURI;
  final String? coverDisplay;
  final String mintBlockchain;
  final AlumniAccount? curatorAlumni;
  final List<AlumniAccount>? curatorsAlumni;
  final List<AlumniAccount>? artistsAlumni;
  final List<FFSeries>? series;
  final List<FFContract>? contracts;
  final AlumniAccount? partnerAlumni;
  final String type;
  final List<Post>? posts;
  final int status;

  Exhibition({
    required this.id,
    required this.title,
    required this.slug,
    required this.exhibitionStartAt,
    required this.previewDuration,
    required this.noteTitle,
    required this.noteBrief,
    required this.note,
    required this.mintBlockchain,
    required this.type,
    required this.status,
    required this.coverURI,
    this.coverDisplay,
    this.curatorsAlumni,
    this.artistsAlumni,
    this.series,
    this.contracts,
    this.partnerAlumni,
    this.curatorAlumni,
    this.posts,
  });

  factory Exhibition.fromJson(Map<String, dynamic> json) => Exhibition(
        id: json['id'] as String,
        title: json['title'] as String,
        slug: json['slug'] as String,
        exhibitionStartAt: DateTime.parse(json['exhibitionStartAt'] as String),
        previewDuration: json['previewDuration'] as int?,
        noteTitle: json['noteTitle'] as String?,
        noteBrief: json['noteBrief'] as String?,
        note: json['note'] as String?,
        coverURI: json['coverURI'] as String? ?? '',
        coverDisplay: json['coverDisplay'] as String?,
        curatorsAlumni: (json['curatorsAlumni'] as List<dynamic>?)
            ?.map((e) => AlumniAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        artistsAlumni: (json['artistsAlumni'] as List<dynamic>?)
            ?.map((e) => AlumniAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        series: (json['series'] as List<dynamic>?)
            ?.map((e) => FFSeries.fromJson(e as Map<String, dynamic>))
            .toList(),
        contracts: (json['contracts'] as List<dynamic>?)
            ?.map((e) => FFContract.fromJson(e as Map<String, dynamic>))
            .toList(),
        mintBlockchain: (json['mintBlockchain'] ?? '') as String,
        partnerAlumni: json['partnerAlumni'] == null
            ? null
            : AlumniAccount.fromJson(json['partner'] as Map<String, dynamic>),
        type: json['type'] as String,
        curatorAlumni: json['curatorAlumni'] == null
            ? null
            : AlumniAccount.fromJson(
                json['curatorAlumni'] as Map<String, dynamic>,
              ),
        posts: (json['posts'] as List<dynamic>?)
            ?.map((e) => Post.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: json['status'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'exhibitionStartAt': exhibitionStartAt.toIso8601String(),
        'previewDuration': previewDuration,
        'noteTitle': noteTitle,
        'noteBrief': noteBrief,
        'note': note,
        'coverURI': coverURI,
        'coverDisplay': coverDisplay,
        'curatorsAlumni': curatorsAlumni?.map((e) => e.toJson()).toList(),
        'artistsAlumni': artistsAlumni?.map((e) => e.toJson()).toList(),
        'series': series?.map((e) => e.toJson()).toList(),
        'contracts': contracts?.map((e) => e.toJson()).toList(),
        'mintBlockchain': mintBlockchain,
        'partnerAlumni': partnerAlumni?.toJson(),
        'type': type,
        'curatorAlumni': curatorAlumni?.toJson(),
        'posts': posts?.map((e) => e.toJson()).toList(),
        'status': status,
      };

  Exhibition copyWith({
    String? id,
    String? title,
    String? slug,
    DateTime? exhibitionStartAt,
    int? previewDuration,
    String? noteTitle,
    String? noteBrief,
    String? note,
    String? coverURI,
    String? coverDisplay,
    String? thumbnailCoverURI,
    String? mintBlockchain,
    AlumniAccount? curatorAlumni,
    List<AlumniAccount>? curatorsAlumni,
    List<AlumniAccount>? artistsAlumni,
    List<FFSeries>? series,
    List<FFContract>? contracts,
    AlumniAccount? partnerAlumni,
    String? type,
    List<Post>? posts,
    int? status,
  }) =>
      Exhibition(
        id: id ?? this.id,
        title: title ?? this.title,
        slug: slug ?? this.slug,
        exhibitionStartAt: exhibitionStartAt ?? this.exhibitionStartAt,
        previewDuration: previewDuration ?? this.previewDuration,
        noteTitle: noteTitle ?? this.noteTitle,
        noteBrief: noteBrief ?? this.noteBrief,
        note: note ?? this.note,
        coverURI: coverURI ?? this.coverURI,
        coverDisplay: coverDisplay ?? this.coverDisplay,
        mintBlockchain: mintBlockchain ?? this.mintBlockchain,
        curatorAlumni: curatorAlumni ?? this.curatorAlumni,
        curatorsAlumni: curatorsAlumni ?? this.curatorsAlumni,
        artistsAlumni: artistsAlumni ?? this.artistsAlumni,
        series: series ?? this.series,
        contracts: contracts ?? this.contracts,
        partnerAlumni: partnerAlumni ?? this.partnerAlumni,
        type: type ?? this.type,
        posts: posts ?? this.posts,
        status: status ?? this.status,
      );
}

class ExhibitionResponse {
  ExhibitionResponse(this.result);

  factory ExhibitionResponse.fromJson(Map<String, dynamic> json) =>
      ExhibitionResponse(
        json['result'] == null
            ? null
            : Exhibition.fromJson(json['result'] as Map<String, dynamic>),
      );
  final Exhibition? result;

  Map<String, dynamic> toJson() => {
        'result': result,
      };
}

class ListExhibitionResponse {
  ListExhibitionResponse(this.result);

  factory ListExhibitionResponse.fromJson(Map<String, dynamic> json) {
    final list = json['result'] as List<dynamic>;
    return ListExhibitionResponse(
      list
          .map((e) => Exhibition.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  final List<Exhibition> result;
}

class ExhibitionDetail {
  ExhibitionDetail({required this.exhibition, this.artworks});

  final Exhibition exhibition;
  List<Artwork>? artworks;

  ExhibitionDetail copyWith({
    Exhibition? exhibition,
    List<Artwork>? artworks,
  }) =>
      ExhibitionDetail(
        exhibition: exhibition ?? this.exhibition,
        artworks: artworks ?? this.artworks,
      );
}

class Resource {
  Resource({required this.id});

  final String id;
}

class Post extends Resource {
  Post({
    required super.id,
    required this.type,
    required this.slug,
    required this.title,
    required this.content,
    required this.coverURI,
    required this.createdAt,
    required this.updatedAt,
    this.dateTime,
    this.description,
    this.author,
    this.displayIndex,
    this.exhibitionID,
    this.exhibition,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        type: json['type'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        coverURI: json['coverURI'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        dateTime: json['dateTime'] == null
            ? null
            : DateTime.parse(json['dateTime'] as String),
        description: json['description'] as String?,
        author: json['author'] as String?,
        displayIndex: json['displayIndex'] as int?,
        exhibitionID: json['exhibitionID'] as String?,
        exhibition: json['exhibition'] == null
            ? null
            : Exhibition.fromJson(
                Map<String, dynamic>.from(json['exhibition'] as Map),
              ),
      );
  final String type;
  final String slug;
  final String title;
  final String content;
  final int? displayIndex;
  final String? coverURI;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dateTime;
  final String? description;
  final String? author;
  final String? exhibitionID;
  final Exhibition? exhibition;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'slug': slug,
        'title': title,
        'content': content,
        'coverURI': coverURI,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'dateTime': dateTime?.toIso8601String(),
        'description': description,
        'author': author,
        'displayIndex': displayIndex,
        'exhibitionID': exhibitionID,
        'exhibition': exhibition?.toJson(),
      };
}

class CustomExhibitionNote extends Resource {
  CustomExhibitionNote({
    required super.id,
    required this.title,
    required this.content,
    this.canReadMore,
    this.readMoreUrl,
  });

  factory CustomExhibitionNote.fromJson(Map<String, dynamic> json) =>
      CustomExhibitionNote(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        canReadMore: json['canReadMore'] as bool? ?? false,
        readMoreUrl: json['readMoreUrl'] as String?,
      );
  final String title;
  final String content;
  final bool? canReadMore;
  final String? readMoreUrl;
}

enum MediaType {
  image,
  video,
}

extension PostExt on Post {
  MediaType? get mediaType {
    if (coverURI == null) {
      return null;
    }
    final url = Uri.parse(coverURI!);
    if (YOUTUBE_DOMAINS.any((domain) => url.host.contains(domain))) {
      return MediaType.video;
    }
    return MediaType.image;
  }

  String get displayType =>
      type == 'close-up' ? 'close_up'.tr() : type.capitalize();

  List<String> get thumbnailUrls {
    if (coverURI == null) {
      return [];
    }
    if (mediaType == MediaType.image) {
      return [getFFUrl(coverURI!)];
    } else {
      final thumbUrls = <String>[];
      final videoId = Uri.parse(coverURI!).queryParameters['v'];
      for (final variant in YOUTUBE_VARIANTS) {
        final url = 'https://img.youtube.com/vi/$videoId/$variant.jpg';
        thumbUrls.add(url);
      }
      return thumbUrls;
    }
  }

  String get previewUrl {
    if (coverURI == null) {
      return '';
    }
    if (mediaType == MediaType.image) {
      return getFFUrl(coverURI!);
    } else {
      final videoId = Uri.parse(coverURI!).queryParameters['v'];
      return 'https://www.youtube.com/embed/$videoId?autoplay=1&loop=1&controls=0';
    }
  }
}
