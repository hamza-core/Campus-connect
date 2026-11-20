/// In-memory snapshots of what screens last showed, so switching tabs paints the
/// last-known data instantly and refreshes it in the background instead of
/// flashing a loading placeholder. Cleared whenever the signed-in user changes.
final class SessionCache {
  final _data = <Object, Object?>{};

  T? read<T>(Object key) {
    final value = _data[key];
    return value is T ? value : null;
  }

  void write(Object key, Object? value) => _data[key] = value;

  void clear() => _data.clear();
}
