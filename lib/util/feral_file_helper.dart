// import 'package:autonomy_flutter/common/environment.dart';
// import 'package:autonomy_flutter/common/injector.dart';
// import 'package:autonomy_flutter/service/remote_config_service.dart';

// class FeralFileHelper {
//   static final String _baseUrl = Environment.feralFileAPIURL;

//   static String getArtistUrl(String alias) => '$_baseUrl/artists/$alias';

//   static String getCuratorUrl(String alias) => '$_baseUrl/curators/$alias';

//   static String getExhibitionNoteUrl(String exhibitionSlug) =>
//       '$_baseUrl/exhibitions/$exhibitionSlug/overview#note';

//   static String getExhibitionForewordUrl(String exhibitionSlug) =>
//       '$_baseUrl/exhibitions/$exhibitionSlug?tab=overview';

//   static String getPostUrl(Post post, String exhibitionID) =>
//       '$_baseUrl/journal/${post.type}/${post.slug}/?exhibitionID=$exhibitionID';

//   static List<String> get ongoingExhibitionIDs {
//     final listOngoingExhibitionIDs = injector<RemoteConfigService>()
//         .getConfig<List<dynamic>?>(
//             ConfigGroup.exhibition, ConfigKey.ongoingExhibitionIDs, []);
//     return listOngoingExhibitionIDs?.map((id) => id.toString()).toList() ?? [];
//   }
// }
