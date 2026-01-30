class CacheEntry<T> {
  const CacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class SimpleCache<T> {
  SimpleCache({required Duration ttl}) : _ttl = ttl;

  final Duration _ttl;
  final Map<String, CacheEntry<T>> _store = <String, CacheEntry<T>>{};

  T? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(String key, T value) {
    _store[key] = CacheEntry(value: value, expiresAt: DateTime.now().add(_ttl));
  }

  void remove(String key) {
    _store.remove(key);
  }

  void clear() {
    _store.clear();
  }
}
