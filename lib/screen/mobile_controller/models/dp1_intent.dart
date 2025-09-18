enum DP1Action {
  now,
  schedulePlay;

  String get value {
    switch (this) {
      case DP1Action.now:
        return 'now_display';
      case DP1Action.schedulePlay:
        return 'schedule_play';
    }
  }

  static DP1Action fromString(String value) {
    switch (value) {
      case 'now_display':
        return DP1Action.now;
      case 'schedule_play':
        return DP1Action.schedulePlay;
      default:
        throw ArgumentError('Unknown action type: $value');
    }
  }
}

class DP1Intent {
  DP1Action action;
  DP1Intent({required this.action});

  factory DP1Intent.fromJson(Map<String, dynamic> json) {
    return DP1Intent(
      action: DP1Action.fromString(json['action'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action.value,
      };

  DP1Intent.displayNow() : action = DP1Action.now;
}
