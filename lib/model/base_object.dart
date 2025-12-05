abstract class BaseObject {
  String get key;

  String get value;

  Map<String, String> get toKeyValue => {
        'key': key,
        'value': value,
      };
}
