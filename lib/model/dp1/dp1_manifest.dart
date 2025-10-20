//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

/// DP1 Manifest model following Display Protocol specification
/// Reference: https://github.com/display-protocol/dp1/blob/main/docs/ref-manifest.md
///
/// The DP1 manifest is a JSON document that describes how to display a work.
/// It contains metadata, display controls, and internationalization information.
class DP1Manifest {
  /// Semantic version of manifest schema (required)
  /// Must be a valid semantic version string (e.g., "0.1.0")
  final String refVersion;

  /// Unique identifier for caching purposes (required)
  /// Should be a UUID or other unique string
  final String id;

  /// RFC3339 timestamp when manifest was created (required)
  /// Format: YYYY-MM-DDTHH:MM:SSZ
  final String created;

  /// Default locale for the manifest (required)
  /// Should be a valid BCP 47 language tag (e.g., "en", "en-US")
  final String locale;

  /// Metadata block - human-readable information about the work
  final DP1ManifestMetadata? metadata;

  /// Controls block - display preferences and settings
  final DP1Controls? controls;

  /// Internationalization block - localized text overrides
  final DP1I18n? i18n;

  DP1Manifest({
    required this.refVersion,
    required this.id,
    required this.created,
    required this.locale,
    this.metadata,
    this.controls,
    this.i18n,
  });

  factory DP1Manifest.fromJson(Map<String, dynamic> json) {
    return DP1Manifest(
      refVersion: json['refVersion'] as String,
      id: json['id'] as String,
      created: json['created'] as String,
      locale: json['locale'] as String,
      metadata: json['metadata'] != null
          ? DP1ManifestMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>)
          : null,
      controls: json['controls'] != null
          ? DP1Controls.fromJson(json['controls'] as Map<String, dynamic>)
          : null,
      i18n: json['i18n'] != null
          ? DP1I18n.fromJson(json['i18n'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'refVersion': refVersion,
      'id': id,
      'created': created,
      'locale': locale,
      if (metadata != null) 'metadata': metadata!.toJson(),
      if (controls != null) 'controls': controls!.toJson(),
      if (i18n != null) 'i18n': i18n!.toJson(),
    };
  }

  /// Create a minimal manifest with required fields
  factory DP1Manifest.minimal({
    required String id,
    String refVersion = '0.1.0',
    String locale = 'en',
  }) =>
      DP1Manifest(
        refVersion: refVersion,
        id: id,
        created: DateTime.now().toIso8601String(),
        locale: locale,
      );

  /// Validate the manifest structure according to DP1 specification
  bool get isValid {
    return _isValidRefVersion(refVersion) &&
        id.isNotEmpty &&
        _isValidRfc3339Timestamp(created) &&
        _isValidLocale(locale);
  }

  /// Validate semantic version format (e.g., "0.1.0", "1.0.0")
  static bool _isValidRefVersion(String version) {
    final versionRegex = RegExp(r'^\d+\.\d+\.\d+$');
    return versionRegex.hasMatch(version);
  }

  /// Validate RFC3339 timestamp format
  static bool _isValidRfc3339Timestamp(String timestamp) {
    try {
      DateTime.parse(timestamp);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate BCP 47 language tag format
  static bool _isValidLocale(String locale) {
    // Basic validation for BCP 47 language tags
    final localeRegex = RegExp(r'^[a-z]{2}(-[A-Z]{2})?$');
    return localeRegex.hasMatch(locale);
  }

  /// Get the maximum recommended manifest size in bytes (64 KB)
  static int get maxRecommendedSize => 64 * 1024;

  /// Check if manifest size is within recommended limits
  bool get isWithinSizeLimit {
    final jsonString = toJson().toString();
    return jsonString.length <= maxRecommendedSize;
  }
}

/// Metadata block - carries human-readable information about the work
/// This block contains descriptive information that helps users understand
/// what the work is about and who created it.
class DP1ManifestMetadata {
  /// Work title - the name of the work being displayed
  final String? title;

  /// List of artists who created the work
  /// Each artist can have a name, optional ID, and optional URL
  final List<DP1Artist>? artists;

  /// Credit line - attribution information for the work
  /// Should include copyright information and proper attribution
  final String? creditLine;

  /// Description - detailed information about the work
  /// Can include context, background, or additional details
  final String? description;

  /// Tags - keywords or categories associated with the work
  /// Used for categorization and search purposes
  final List<String>? tags;

  /// Thumbnails with different sizes for preview purposes
  /// Includes small, large, xlarge, and default thumbnail options
  final DP1Thumbnails? thumbnails;

  DP1ManifestMetadata({
    this.title,
    this.artists,
    this.creditLine,
    this.description,
    this.tags,
    this.thumbnails,
  });

  factory DP1ManifestMetadata.fromJson(Map<String, dynamic> json) {
    return DP1ManifestMetadata(
      title: json['title'] as String?,
      artists: json['artists'] != null
          ? (json['artists'] as List)
              .map((e) => DP1Artist.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      creditLine: json['creditLine'] as String?,
      description: json['description'] as String?,
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      thumbnails: json['thumbnails'] != null
          ? DP1Thumbnails.fromJson(json['thumbnails'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (artists != null) 'artists': artists!.map((e) => e.toJson()).toList(),
      if (creditLine != null) 'creditLine': creditLine,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
      if (thumbnails != null) 'thumbnails': thumbnails!.toJson(),
    };
  }
}

/// Artist information - represents a creator of the work
/// Each artist has a required name and optional ID and URL fields
class DP1Artist {
  /// Artist name - the display name of the artist (required)
  final String name;

  /// Artist ID - unique identifier for the artist (optional)
  /// Can be used for linking to artist profiles or databases
  final String? id;

  /// Artist URL - web address for the artist (optional)
  /// Can link to artist's website, portfolio, or social media
  final String? url;

  DP1Artist({
    required this.name,
    this.id,
    this.url,
  });

  factory DP1Artist.fromJson(Map<String, dynamic> json) {
    return DP1Artist(
      name: json['name'] as String,
      id: json['id'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (id != null) 'id': id,
      if (url != null) 'url': url,
    };
  }
}

/// Thumbnails container - holds different sized thumbnail images
/// Provides multiple resolution options for different display contexts
class DP1Thumbnails {
  /// Small thumbnail - typically 150x150 pixels or smaller
  /// Used for small previews, lists, or mobile interfaces
  final DP1Thumbnail? small;

  /// Large thumbnail - typically 300x300 pixels or larger
  /// Used for detailed previews or desktop interfaces
  final DP1Thumbnail? large;

  /// Extra large thumbnail - typically 600x600 pixels or larger
  /// Used for high-resolution displays or detailed views
  final DP1Thumbnail? xlarge;

  /// Default thumbnail - fallback option when specific size not available
  /// Should be a reasonable size for general use
  final DP1Thumbnail? defaultThumbnail;

  DP1Thumbnails({
    this.small,
    this.large,
    this.xlarge,
    this.defaultThumbnail,
  });

  factory DP1Thumbnails.fromJson(Map<String, dynamic> json) {
    return DP1Thumbnails(
      small: json['small'] != null
          ? DP1Thumbnail.fromJson(json['small'] as Map<String, dynamic>)
          : null,
      large: json['large'] != null
          ? DP1Thumbnail.fromJson(json['large'] as Map<String, dynamic>)
          : null,
      xlarge: json['xlarge'] != null
          ? DP1Thumbnail.fromJson(json['xlarge'] as Map<String, dynamic>)
          : null,
      defaultThumbnail: json['default'] != null
          ? DP1Thumbnail.fromJson(json['default'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (small != null) 'small': small!.toJson(),
      if (large != null) 'large': large!.toJson(),
      if (xlarge != null) 'xlarge': xlarge!.toJson(),
      if (defaultThumbnail != null) 'default': defaultThumbnail!.toJson(),
    };
  }
}

/// Individual thumbnail - represents a single thumbnail image
/// Contains URI, dimensions, and optional integrity check
class DP1Thumbnail {
  /// URI to the thumbnail image (required)
  /// Should be a valid HTTP/HTTPS URL or data URI
  final String uri;

  /// Width in pixels (required)
  /// Specifies the horizontal dimension of the thumbnail
  final int? w;

  /// Height in pixels (required)
  /// Specifies the vertical dimension of the thumbnail
  final int? h;

  /// SHA256 checksum for integrity verification (optional)
  /// Used to verify the thumbnail hasn't been tampered with
  final String? sha256;

  DP1Thumbnail({
    required this.uri,
    this.w,
    this.h,
    this.sha256,
  });

  factory DP1Thumbnail.fromJson(Map<String, dynamic> json) {
    return DP1Thumbnail(
      uri: json['uri'] as String,
      w: json['w'] as int?,
      h: json['h'] as int?,
      sha256: json['sha256'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      if (w != null) 'w': w,
      if (h != null) 'h': h,
      if (sha256 != null) 'sha256': sha256,
    };
  }
}

/// Controls block - defines display preferences and safety settings
/// This block controls how the work is displayed and any safety constraints
class DP1Controls {
  /// Display settings - controls visual presentation
  /// Includes scaling, margins, background, and interaction settings
  final DP1Display? display;

  /// Safety settings - defines resource limits and constraints
  /// Includes orientation support and resource usage limits
  final DP1Safety? safety;

  DP1Controls({
    this.display,
    this.safety,
  });

  factory DP1Controls.fromJson(Map<String, dynamic> json) {
    return DP1Controls(
      display: json['display'] != null
          ? DP1Display.fromJson(json['display'] as Map<String, dynamic>)
          : null,
      safety: json['safety'] != null
          ? DP1Safety.fromJson(json['safety'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (display != null) 'display': display!.toJson(),
      if (safety != null) 'safety': safety!.toJson(),
    };
  }
}

/// Display settings - controls visual presentation of the work
/// Defines how the work should be scaled, positioned, and interacted with
class DP1Display {
  /// Scaling mode - how the work should be scaled to fit the display
  /// Values: "fit" (maintain aspect ratio, fit within bounds) or "fill" (fill entire display)
  final String? scaling;

  /// Margin - spacing around the work
  /// Can be specified as CSS margin values (e.g., "10px", "1em")
  final String? margin;

  /// Background color - color to display behind the work
  /// Should be a valid CSS color value (e.g., "#000000", "rgb(0,0,0)", "black")
  final String? background;

  /// Autoplay setting - whether media should start playing automatically
  /// true = start playing immediately, false = wait for user interaction
  final bool? autoplay;

  /// Loop setting - whether media should repeat when finished
  /// true = repeat indefinitely, false = play once
  final bool? loop;

  /// Interaction settings - defines user interaction capabilities
  /// Includes keyboard shortcuts and mouse interaction options
  final DP1Interaction? interaction;

  DP1Display({
    this.scaling,
    this.margin,
    this.background,
    this.autoplay,
    this.loop,
    this.interaction,
  });

  factory DP1Display.fromJson(Map<String, dynamic> json) {
    return DP1Display(
      scaling: json['scaling'] as String?,
      margin: json['margin'] as String?,
      background: json['background'] as String?,
      autoplay: json['autoplay'] as bool?,
      loop: json['loop'] as bool?,
      interaction: json['interaction'] != null
          ? DP1Interaction.fromJson(json['interaction'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (scaling != null) 'scaling': scaling,
      if (margin != null) 'margin': margin,
      if (background != null) 'background': background,
      if (autoplay != null) 'autoplay': autoplay,
      if (loop != null) 'loop': loop,
      if (interaction != null) 'interaction': interaction!.toJson(),
    };
  }
}

/// Interaction settings - defines user interaction capabilities
/// Controls how users can interact with the work using keyboard and mouse
class DP1Interaction {
  /// Keyboard interactions - list of supported keyboard shortcuts
  /// Each string represents a key combination (e.g., "space", "ctrl+s", "arrow-left")
  final List<String>? keyboard;

  /// Mouse interactions - defines mouse interaction capabilities
  /// Can include click, drag, scroll, and other mouse-based interactions
  final Map<String, dynamic>? mouse;

  DP1Interaction({
    this.keyboard,
    this.mouse,
  });

  factory DP1Interaction.fromJson(Map<String, dynamic> json) {
    return DP1Interaction(
      keyboard: json['keyboard'] != null
          ? List<String>.from(json['keyboard'] as List)
          : null,
      mouse: json['mouse'] != null
          ? Map<String, dynamic>.from(json['mouse'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (keyboard != null) 'keyboard': keyboard,
      if (mouse != null) 'mouse': mouse,
    };
  }
}

/// Safety settings - defines resource limits and constraints
/// Ensures the work doesn't exceed system capabilities or cause issues
class DP1Safety {
  /// Supported orientations - which screen orientations are supported
  /// Values can include: "portrait", "landscape", "portrait-upsidedown", "landscape-left", "landscape-right"
  final List<String>? orientation;

  /// Maximum CPU percentage - maximum CPU usage allowed (0-100)
  /// Helps prevent the work from consuming too many system resources
  final int? maxCpuPct;

  /// Maximum memory in MB - maximum memory usage allowed
  /// Helps prevent the work from consuming too much system memory
  final int? maxMemMB;

  DP1Safety({
    this.orientation,
    this.maxCpuPct,
    this.maxMemMB,
  });

  factory DP1Safety.fromJson(Map<String, dynamic> json) {
    return DP1Safety(
      orientation: json['orientation'] != null
          ? List<String>.from(json['orientation'] as List)
          : null,
      maxCpuPct: json['maxCpuPct'] as int?,
      maxMemMB: json['maxMemMB'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orientation != null) 'orientation': orientation,
      if (maxCpuPct != null) 'maxCpuPct': maxCpuPct,
      if (maxMemMB != null) 'maxMemMB': maxMemMB,
    };
  }
}

/// Internationalization block - provides localized text overrides
/// Allows the same work to be displayed with different text in different languages
class DP1I18n {
  /// Localized content by language code
  /// Keys are BCP 47 language tags (e.g., "en", "en-US", "fr", "ja")
  /// Values contain the localized versions of text fields
  final Map<String, DP1LocalizedContent>? locales;

  DP1I18n({
    this.locales,
  });

  factory DP1I18n.fromJson(Map<String, dynamic> json) {
    return DP1I18n(
      locales: json.isNotEmpty
          ? json.map((key, value) => MapEntry(
                key,
                DP1LocalizedContent.fromJson(value as Map<String, dynamic>),
              ))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return locales?.map((key, value) => MapEntry(key, value.toJson())) ?? {};
  }
}

/// Localized content for a specific language
/// Contains translated versions of text fields from the metadata block
class DP1LocalizedContent {
  /// Localized title - translated version of the work title
  final String? title;

  /// Localized description - translated version of the work description
  final String? description;

  /// Localized credit line - translated version of the credit line
  final String? creditLine;

  /// Additional localized fields - any other localized text content
  /// Can include custom fields specific to the work or application
  final Map<String, dynamic>? additional;

  DP1LocalizedContent({
    this.title,
    this.description,
    this.creditLine,
    this.additional,
  });

  factory DP1LocalizedContent.fromJson(Map<String, dynamic> json) {
    return DP1LocalizedContent(
      title: json['title'] as String?,
      description: json['description'] as String?,
      creditLine: json['creditLine'] as String?,
      additional: json.isNotEmpty ? Map<String, dynamic>.from(json) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (creditLine != null) 'creditLine': creditLine,
      if (additional != null) ...additional!,
    };
  }
}

/// Extension methods for DP1Manifest - provides convenient helper methods
/// These methods make it easier to work with DP1 manifests in common scenarios
extension DP1ManifestExtension on DP1Manifest {
  /// Check if manifest has metadata block
  bool get hasMetadata => metadata != null;

  /// Check if manifest has controls block
  bool get hasControls => controls != null;

  /// Check if manifest has internationalization block
  bool get hasI18n => i18n != null;

  /// Get localized content for a specific locale
  /// Returns null if the locale is not available
  DP1LocalizedContent? getLocalizedContent(String locale) {
    return i18n?.locales?[locale];
  }

  /// Get Artists
  /// Returns a list of artist
  List<String> get artistNames {
    if (metadata?.artists == null) return [];
    return metadata!.artists!.map((artist) => artist.name).toList();
  }

  /// Get thumbnail by size preference
  /// Returns the best available thumbnail for the requested size
  DP1Thumbnail? getThumbnail(String size) {
    switch (size.toLowerCase()) {
      case 'small':
        return metadata?.thumbnails?.small;
      case 'large':
        return metadata?.thumbnails?.large;
      case 'xlarge':
        return metadata?.thumbnails?.xlarge;
      case 'default':
        return metadata?.thumbnails?.defaultThumbnail;
      default:
        // Return default thumbnail as fallback
        return metadata?.thumbnails?.defaultThumbnail;
    }
  }

  /// Get the best available thumbnail (prefers default, then large, then small)
  DP1Thumbnail? getBestThumbnail() {
    return metadata?.thumbnails?.defaultThumbnail ??
        metadata?.thumbnails?.large ??
        metadata?.thumbnails?.small ??
        metadata?.thumbnails?.xlarge;
  }

  /// Check if the manifest supports a specific orientation
  bool supportsOrientation(String orientation) {
    return controls?.safety?.orientation?.contains(orientation) ?? true;
  }

  /// Get the effective title (localized if available, otherwise default)
  String? getEffectiveTitle(String? preferredLocale) {
    if (preferredLocale != null) {
      final localized = getLocalizedContent(preferredLocale);
      if (localized?.title != null) {
        return localized!.title;
      }
    }
    return metadata?.title;
  }

  /// Get the effective description (localized if available, otherwise default)
  String? getEffectiveDescription(String? preferredLocale) {
    if (preferredLocale != null) {
      final localized = getLocalizedContent(preferredLocale);
      if (localized?.description != null) {
        return localized!.description;
      }
    }
    return metadata?.description;
  }

  /// Get the effective credit line (localized if available, otherwise default)
  String? getEffectiveCreditLine(String? preferredLocale) {
    if (preferredLocale != null) {
      final localized = getLocalizedContent(preferredLocale);
      if (localized?.creditLine != null) {
        return localized!.creditLine;
      }
    }
    return metadata?.creditLine;
  }
}
