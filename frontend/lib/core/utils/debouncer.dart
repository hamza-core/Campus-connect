import 'dart:async';

final class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 350)});

  final Duration delay;
  Timer? _timer;
  bool _disposed = false;

  void schedule(void Function() callback) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      callback();
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
