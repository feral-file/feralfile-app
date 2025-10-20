//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

/// DP1 Manifest model following Display Protocol specification
/// Reference: https://github.com/display-protocol/dp1/blob/main/docs/ref-manifest.md
class DP1Manifest {
  /// The version of the DP1 manifest specification
  final String dp1Version;

  /// Unique identifier for the manifest
  final String id;

  /// Human-readable name of the display content
  final String name;

  /// Description of the display content
  final String? description;

  /// Version of the content
  final String? version;

  /// Author information
  final DP1Author? author;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Last update timestamp
  final DateTime? updatedAt;

  /// Display settings and configuration
  final DP1DisplaySettings? display;

  /// Resources (assets) used in the display
  final List<DP1Resource>? resources;

  /// Layout definitions
  final List<DP1Layout>? layouts;

  /// Interaction definitions
  final List<DP1Interaction>? interactions;

  /// Metadata and custom properties
  final Map<String, dynamic>? metadata;

  /// Tags for categorization
  final List<String>? tags;

  /// License information
  final String? license;

  /// Thumbnail URL for the display content
  final String? thumbnail;

  /// Preview URL for the display content
  final String? preview;

  DP1Manifest({
    required this.dp1Version,
    required this.id,
    required this.name,
    this.description,
    this.version,
    this.author,
    this.createdAt,
    this.updatedAt,
    this.display,
    this.resources,
    this.layouts,
    this.interactions,
    this.metadata,
    this.tags,
    this.license,
    this.thumbnail,
    this.preview,
  });

  factory DP1Manifest.fromJson(Map<String, dynamic> json) {
    return DP1Manifest(
      dp1Version: json['dp1_version'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      version: json['version'] as String?,
      author: json['author'] != null
          ? DP1Author.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      display: json['display'] != null
          ? DP1DisplaySettings.fromJson(json['display'] as Map<String, dynamic>)
          : null,
      resources: json['resources'] != null
          ? (json['resources'] as List)
              .map((e) => DP1Resource.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      layouts: json['layouts'] != null
          ? (json['layouts'] as List)
              .map((e) => DP1Layout.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      interactions: json['interactions'] != null
          ? (json['interactions'] as List)
              .map((e) => DP1Interaction.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      tags:
          json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      license: json['license'] as String?,
      thumbnail: json['thumbnail'] as String?,
      preview: json['preview'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dp1_version': dp1Version,
      'id': id,
      'name': name,
      'description': description,
      'version': version,
      'author': author?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'display': display?.toJson(),
      'resources': resources?.map((e) => e.toJson()).toList(),
      'layouts': layouts?.map((e) => e.toJson()).toList(),
      'interactions': interactions?.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      'tags': tags,
      'license': license,
      'thumbnail': thumbnail,
      'preview': preview,
    };
  }

  /// Create a minimal manifest with required fields
  factory DP1Manifest.minimal({
    required String id,
    required String name,
    String dp1Version = '1.0.0',
  }) =>
      DP1Manifest(
        dp1Version: dp1Version,
        id: id,
        name: name,
        createdAt: DateTime.now(),
      );

  /// Validate the manifest structure
  bool get isValid {
    return dp1Version.isNotEmpty && id.isNotEmpty && name.isNotEmpty;
  }
}

/// Author information for the manifest
class DP1Author {
  /// Author name
  final String name;

  /// Author email
  final String? email;

  /// Author website
  final String? website;

  /// Author social media handles
  final Map<String, String>? social;

  DP1Author({
    required this.name,
    this.email,
    this.website,
    this.social,
  });

  factory DP1Author.fromJson(Map<String, dynamic> json) {
    return DP1Author(
      name: json['name'] as String,
      email: json['email'] as String?,
      website: json['website'] as String?,
      social: json['social'] != null
          ? Map<String, String>.from(json['social'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'website': website,
      'social': social,
    };
  }
}

/// Display settings and configuration
class DP1DisplaySettings {
  /// Display dimensions
  final DP1Dimensions? dimensions;

  /// Background color or image
  final String? background;

  /// Display duration in seconds
  final int? duration;

  /// Auto-play settings
  final bool? autoPlay;

  /// Loop settings
  final bool? loop;

  /// Transition effects
  final List<String>? transitions;

  /// Display orientation
  final String? orientation;

  DP1DisplaySettings({
    this.dimensions,
    this.background,
    this.duration,
    this.autoPlay,
    this.loop,
    this.transitions,
    this.orientation,
  });

  factory DP1DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DP1DisplaySettings(
      dimensions: json['dimensions'] != null
          ? DP1Dimensions.fromJson(json['dimensions'] as Map<String, dynamic>)
          : null,
      background: json['background'] as String?,
      duration: json['duration'] as int?,
      autoPlay: json['auto_play'] as bool?,
      loop: json['loop'] as bool?,
      transitions: json['transitions'] != null
          ? List<String>.from(json['transitions'] as List)
          : null,
      orientation: json['orientation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dimensions': dimensions?.toJson(),
      'background': background,
      'duration': duration,
      'auto_play': autoPlay,
      'loop': loop,
      'transitions': transitions,
      'orientation': orientation,
    };
  }
}

/// Display dimensions
class DP1Dimensions {
  /// Width in pixels
  final int width;

  /// Height in pixels
  final int height;

  /// Aspect ratio
  final String? aspectRatio;

  DP1Dimensions({
    required this.width,
    required this.height,
    this.aspectRatio,
  });

  factory DP1Dimensions.fromJson(Map<String, dynamic> json) {
    return DP1Dimensions(
      width: json['width'] as int,
      height: json['height'] as int,
      aspectRatio: json['aspect_ratio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'aspect_ratio': aspectRatio,
    };
  }
}

/// Resource definition for assets
class DP1Resource {
  /// Unique identifier for the resource
  final String id;

  /// Resource type (image, video, audio, text, etc.)
  final String type;

  /// Resource URL or path
  final String url;

  /// Resource metadata
  final Map<String, dynamic>? metadata;

  /// Resource dimensions
  final DP1Dimensions? dimensions;

  /// File size in bytes
  final int? size;

  /// MIME type
  final String? mimeType;

  /// Checksum for integrity verification
  final String? checksum;

  /// Alternative text for accessibility
  final String? altText;

  DP1Resource({
    required this.id,
    required this.type,
    required this.url,
    this.metadata,
    this.dimensions,
    this.size,
    this.mimeType,
    this.checksum,
    this.altText,
  });

  factory DP1Resource.fromJson(Map<String, dynamic> json) {
    return DP1Resource(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      dimensions: json['dimensions'] != null
          ? DP1Dimensions.fromJson(json['dimensions'] as Map<String, dynamic>)
          : null,
      size: json['size'] as int?,
      mimeType: json['mime_type'] as String?,
      checksum: json['checksum'] as String?,
      altText: json['alt_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'metadata': metadata,
      'dimensions': dimensions?.toJson(),
      'size': size,
      'mime_type': mimeType,
      'checksum': checksum,
      'alt_text': altText,
    };
  }
}

/// Layout definition
class DP1Layout {
  /// Layout identifier
  final String id;

  /// Layout name
  final String name;

  /// Layout type
  final String type;

  /// Layout configuration
  final Map<String, dynamic>? config;

  /// Resources used in this layout
  final List<String>? resources;

  /// Layout positioning
  final DP1Position? position;

  /// Layout styling
  final Map<String, dynamic>? style;

  DP1Layout({
    required this.id,
    required this.name,
    required this.type,
    this.config,
    this.resources,
    this.position,
    this.style,
  });

  factory DP1Layout.fromJson(Map<String, dynamic> json) {
    return DP1Layout(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      config: json['config'] != null
          ? Map<String, dynamic>.from(json['config'] as Map)
          : null,
      resources: json['resources'] != null
          ? List<String>.from(json['resources'] as List)
          : null,
      position: json['position'] != null
          ? DP1Position.fromJson(json['position'] as Map<String, dynamic>)
          : null,
      style: json['style'] != null
          ? Map<String, dynamic>.from(json['style'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'config': config,
      'resources': resources,
      'position': position?.toJson(),
      'style': style,
    };
  }
}

/// Position information
class DP1Position {
  /// X coordinate
  final double x;

  /// Y coordinate
  final double y;

  /// Z index for layering
  final int? z;

  /// Rotation in degrees
  final double? rotation;

  /// Scale factor
  final double? scale;

  DP1Position({
    required this.x,
    required this.y,
    this.z,
    this.rotation,
    this.scale,
  });

  factory DP1Position.fromJson(Map<String, dynamic> json) {
    return DP1Position(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: json['z'] as int?,
      rotation: json['rotation'] != null
          ? (json['rotation'] as num).toDouble()
          : null,
      scale: json['scale'] != null ? (json['scale'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'rotation': rotation,
      'scale': scale,
    };
  }
}

/// Interaction definition
class DP1Interaction {
  /// Interaction identifier
  final String id;

  /// Interaction type (click, hover, touch, etc.)
  final String type;

  /// Target element or resource
  final String? target;

  /// Interaction action
  final String? action;

  /// Interaction parameters
  final Map<String, dynamic>? params;

  /// Interaction conditions
  final Map<String, dynamic>? conditions;

  DP1Interaction({
    required this.id,
    required this.type,
    this.target,
    this.action,
    this.params,
    this.conditions,
  });

  factory DP1Interaction.fromJson(Map<String, dynamic> json) {
    return DP1Interaction(
      id: json['id'] as String,
      type: json['type'] as String,
      target: json['target'] as String?,
      action: json['action'] as String?,
      params: json['params'] != null
          ? Map<String, dynamic>.from(json['params'] as Map)
          : null,
      conditions: json['conditions'] != null
          ? Map<String, dynamic>.from(json['conditions'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'target': target,
      'action': action,
      'params': params,
      'conditions': conditions,
    };
  }
}

/// Extension methods for DP1Manifest
extension DP1ManifestExtension on DP1Manifest {
  /// Get resource by ID
  DP1Resource? getResourceById(String id) {
    return resources?.firstWhere(
      (resource) => resource.id == id,
      orElse: () => throw StateError('Resource not found'),
    );
  }

  /// Get layout by ID
  DP1Layout? getLayoutById(String id) {
    return layouts?.firstWhere(
      (layout) => layout.id == id,
      orElse: () => throw StateError('Layout not found'),
    );
  }

  /// Get interaction by ID
  DP1Interaction? getInteractionById(String id) {
    return interactions?.firstWhere(
      (interaction) => interaction.id == id,
      orElse: () => throw StateError('Interaction not found'),
    );
  }

  /// Check if manifest has resources
  bool get hasResources => resources != null && resources!.isNotEmpty;

  /// Check if manifest has layouts
  bool get hasLayouts => layouts != null && layouts!.isNotEmpty;

  /// Check if manifest has interactions
  bool get hasInteractions => interactions != null && interactions!.isNotEmpty;
}
