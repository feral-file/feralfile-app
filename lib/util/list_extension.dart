extension Unique<E, Id> on List<E> {
  List<E> unique([Id Function(E element)? id, bool inplace = true]) {
    final ids = <Id>{};
    final list = inplace ? this : List<E>.from(this)
      ..retainWhere((x) => ids.add(id != null ? id(x) : x as Id));
    return list;
  }
}

extension ListGroupBy<T extends Object> on List<T> {
  Map<String, List<T>> groupBy(String Function(T change) param0) {
    final map = <String, List<T>>{};
    for (final item in this) {
      final key = param0(item);
      map[key] = (map[key] ?? []).toList()..add(item);
    }
    return map;
  }
}
