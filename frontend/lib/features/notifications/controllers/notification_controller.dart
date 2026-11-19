import 'dart:async';

import '../../../core/controllers/base_controller.dart';
import '../../../data/realtime/notification_realtime.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../domain/models/app_notification.dart';

final class NotificationController extends BaseController {
  NotificationController(this._repository, this._realtime);

  final NotificationRepository _repository;
  final NotificationRealtime _realtime;

  List<AppNotification> items = const [];
  int unreadCount = 0;
  bool connected = false;

  /// The most recent live notification (used to show a pop-up).
  AppNotification? latest;

  StreamSubscription<AppNotification>? _subscription;
  Timer? _retry;
  bool _active = false;
  bool _hadFailure = false;

  /// Loads the list and opens the live connection. Safe to call repeatedly.
  Future<void> start() async {
    if (_active) return;
    _active = true;
    _subscription = _realtime.events.listen(_onEvent);
    await load();
    await _connect();
  }

  Future<void> _connect() async {
    if (!_active) return;
    try {
      await _realtime.start();
      connected = true;
      _retry?.cancel();
      // After an outage, catch anything that arrived while we were offline.
      if (_hadFailure) unawaited(load());
      _hadFailure = false;
    } on Object {
      connected = false;
      _hadFailure = true;
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 15), _connect);
    }
    safeNotify();
  }

  void _onEvent(AppNotification notification) {
    if (items.any((item) => item.id == notification.id)) return;
    items = List.unmodifiable([notification, ...items]);
    if (!notification.read) unreadCount++;
    latest = notification;
    safeNotify();
  }

  Future<void> load() => run<NotificationPage>(
    _repository.list,
    onSuccess: (page) {
      items = page.items;
      unreadCount = page.unreadCount;
    },
  );

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    final previous = (items, unreadCount);
    items = List.unmodifiable([for (final item in items) item.asRead()]);
    unreadCount = 0;
    safeNotify();
    try {
      await _repository.markAllRead();
    } on Object {
      items = previous.$1;
      unreadCount = previous.$2;
      safeNotify();
    }
  }

  Future<void> stop() async {
    _active = false;
    _retry?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    connected = false;
    items = const [];
    unreadCount = 0;
    latest = null;
    safeNotify();
    try {
      await _realtime.stop();
    } on Object {
      // Ignore: the connection is being discarded anyway.
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
