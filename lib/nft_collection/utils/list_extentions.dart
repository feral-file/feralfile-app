extension Unique<E, Id> on List<E>? {
  List<E>? unique([Id Function(E element)? id, bool inplace = true]) {
    final ids = <dynamic>{};
    final list = inplace
        ? this
        : this != null
            ? List<E>.from(this!)
            : null;
    list?.retainWhere((x) => ids.add(id != null ? id(x) : x as Id));
    return list;
  }
}

extension NullableListExtensions<T> on List<T>? {
  T? atIndexOrNull(int index) {
    if (this == null || index < 0 || index >= this!.length) {
      return null;
    }
    return this![index];
  }
}

extension ListExtensions<T> on List<T> {
  List<List<T>> batch(int batchSize) {
    if (batchSize <= 0) throw ArgumentError("Batch size must be positive");
    List<List<T>> result = [];
    for (var i = 0; i < length; i += batchSize) {
      var end = (i + batchSize).clamp(0, length);
      result.add(sublist(i, end));
    }
    return result;
  }
}
