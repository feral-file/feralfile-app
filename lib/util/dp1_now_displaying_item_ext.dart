import 'package:autonomy_flutter/model/dp1/dp1_manifest.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';

extension DP1NowDisplayingItemExt on DP1NowDisplayingItem {
  /// Get the best available thumbnail from the manifest, or null if not present
  DP1Thumbnail? get thumbnail {
    DP1Thumbnail? thumb;
    thumb = dp1Manifest?.getThumbnail('small');
    if (thumb != null) return thumb;

    final thumbnailUrl = assetToken?.getGalleryThumbnailUrl();
    if (thumbnailUrl != null) {
      thumb = DP1Thumbnail(uri: thumbnailUrl);
    }

    return thumb;
  }

  /// Get the effective title from the manifest, using the preferred locale if available
  String? get title {
    // If there is a preferred locale in DP1NowDisplayingItem, use it; otherwise fall back to default
    // This assumes DP1NowDisplayingItem has a preferredLocale property, otherwise just use manifest?.metadata?.title
    return dp1Item.title ?? assetToken?.displayTitle;
  }

  /// Get list of artist names from the manifest
  List<DP1Artist> get artists {
    final manifestArtists = dp1Manifest?.metadata?.artists;
    if (manifestArtists != null) {
      return manifestArtists;
    }

    final indexerArtist = assetToken?.artist;

    if (indexerArtist == null) {
      return [];
    }
    final artist = DP1Artist(
        name: indexerArtist.name, url: indexerArtist.url, id: indexerArtist.id);
    return [artist];
  }

  bool get canInteract {
    return assetToken != null && assetToken!.canInteract;
  }
}
