enum AiAction {
  now,
  schedulePlay,
  openScreen,
  addAddress;

  String get value {
    switch (this) {
      case AiAction.now:
        return 'now_display';
      case AiAction.schedulePlay:
        return 'schedule_play';
      case AiAction.openScreen:
        return 'open_screen';
      case AiAction.addAddress:
        return 'add_address';
    }
  }

  static AiAction fromString(String value) {
    switch (value) {
      case 'now_display':
        return AiAction.now;
      case 'schedule_play':
        return AiAction.schedulePlay;
      case 'open_screen':
        return AiAction.openScreen;
      case 'add_address':
        return AiAction.addAddress;
      default:
        throw ArgumentError('Unknown action type: $value');
    }
  }
}

enum AiEntityType {
  artist,
  exhibition,
  channel,
  playlist,
  myCollection,
  address;

  String get value {
    switch (this) {
      case AiEntityType.artist:
        return 'artist';
      case AiEntityType.exhibition:
        return 'exhibition';
      case AiEntityType.channel:
        return 'channel';
      case AiEntityType.playlist:
        return 'playlist';
      case AiEntityType.myCollection:
        return 'my_collection';
      case AiEntityType.address:
        return 'address';
    }
  }

  static AiEntityType fromString(String value) {
    switch (value) {
      case 'artist':
        return AiEntityType.artist;
      case 'exhibition':
        return AiEntityType.exhibition;
      case 'channel':
        return AiEntityType.channel;
      case 'playlist':
        return AiEntityType.playlist;
      case 'my_collection':
        return AiEntityType.myCollection;
      case 'address':
        return AiEntityType.address;
      default:
        return AiEntityType.artist;
    }
  }
}

class AiEntity {
  AiEntity({
    required this.name,
    required this.type,
    required this.probability,
    this.slug,
    this.ids,
  });

  factory AiEntity.fromJson(Map<String, dynamic> json) {
    return AiEntity(
      name: json['name'] as String,
      type: AiEntityType.fromString(json['type'] as String),
      probability: (json['probability'] as num).toDouble(),
      slug: json['slug'] as String?,
      ids: json['ids'] == null
          ? null
          : (json['ids'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  final String name;
  final AiEntityType type;
  final double probability;
  final String? slug;
  final List<String>? ids;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.value,
      'probability': probability,
      'slug': slug,
      'ids': ids,
    };
  }
}

class AiIntent {
  AiIntent({
    required this.action,
    this.deviceName,
    this.entities,
    this.searchTerm,
  });

  AiIntent.displayNow({this.deviceName, this.entities, this.searchTerm})
      : action = AiAction.now;

  AiIntent.schedulePlay({this.deviceName, this.entities, this.searchTerm})
      : action = AiAction.schedulePlay;

  factory AiIntent.fromJson(Map<String, dynamic> json) {
    return AiIntent(
      action: AiAction.fromString(json['action'] as String),
      deviceName: json['device_name'] as String?,
      entities: json['entities'] == null
          ? null
          : (json['entities'] as List<dynamic>)
              .map((e) => AiEntity.fromJson(e as Map<String, dynamic>))
              .toList(),
      searchTerm: json['search_term'] as String?,
    );
  }

  final AiAction action;
  final String? deviceName;
  final List<AiEntity>? entities;
  final String? searchTerm;

  Map<String, dynamic> toJson() {
    return {
      'action': action.value,
      'device_name': deviceName,
      'entities': entities?.map((e) => e.toJson()).toList(),
      'search_term': searchTerm,
    };
  }

  String get displayText {
    String prefix = 'Building playlist';
    if (action == AiAction.now) {
      prefix = 'Building playlist';
    } else if (action == AiAction.schedulePlay) {
      prefix = 'Building playlist for scheduled play';
    }

    if (entities != null && entities!.isNotEmpty) {
      final artistNames = entities!.map((e) => e.name).join(', ');
      return '$prefix for artist(s) $artistNames';
    } else if (searchTerm != null && searchTerm!.isNotEmpty) {
      return '$prefix for "$searchTerm"';
    } else {
      return '$prefix';
    }
  }
}
