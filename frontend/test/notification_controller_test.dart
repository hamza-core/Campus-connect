import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/realtime/notification_realtime.dart';
import 'package:project/data/repositories/notification_repository.dart';
import 'package:project/domain/models/app_notification.dart';
import 'package:project/features/notifications/controllers/notification_controller.dart';

AppNotification _n(String id, {bool read = false}) => AppNotification(
  id: id,
  message: 'CC-2026-0001: $id',
  complaintId: 'c1',
  read: read,
  createdAt: DateTime.utc(2026, 11, 19),
);

final class _FakeRepository implements NotificationRepository {
  _FakeRepository(this.page);
  NotificationPage page;
  int markCalls = 0;
  bool failMark = false;

  @override
  Future<NotificationPage> list() async => page;

  @override
  Future<void> markAllRead() async {
    markCalls++;
    if (failMark) throw Exception('offline');
  }
}

final class _FakeRealtime implements NotificationRealtime {
  final controller = StreamController<AppNotification>.broadcast();
  int starts = 0;
  int stops = 0;
  bool failStart = false;

  @override
  Stream<AppNotification> get events => controller.stream;

  @override
  Future<void> start() async {
    starts++;
    if (failStart) throw Exception('no network');
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  test(
    'Loads the list, then adds live notifications and counts unread',
    () async {
      final realtime = _FakeRealtime();
      final controller = NotificationController(
        _FakeRepository(NotificationPage(items: [_n('a')], unreadCount: 1)),
        realtime,
      );
      await controller.start();
      expect(controller.items.map((n) => n.id), ['a']);
      expect(controller.unreadCount, 1);
      expect(controller.connected, isTrue);

      realtime.controller.add(_n('b'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.items.map((n) => n.id), ['b', 'a']);
      expect(controller.unreadCount, 2);
      expect(controller.latest?.id, 'b');

      // The same notification delivered twice is ignored.
      realtime.controller.add(_n('b'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.items.length, 2);
      expect(controller.unreadCount, 2);
      await controller.stop();
    },
  );

  test('Starting twice opens one connection; stopping clears state', () async {
    final realtime = _FakeRealtime();
    final controller = NotificationController(
      _FakeRepository(NotificationPage(items: [_n('a')], unreadCount: 1)),
      realtime,
    );
    await controller.start();
    await controller.start();
    expect(realtime.starts, 1);
    await controller.stop();
    expect(realtime.stops, 1);
    expect(controller.items, isEmpty);
    expect(controller.unreadCount, 0);
  });

  test('Mark all read updates instantly and rolls back on failure', () async {
    final repository = _FakeRepository(
      NotificationPage(items: [_n('a'), _n('b')], unreadCount: 2),
    );
    final controller = NotificationController(repository, _FakeRealtime());
    await controller.start();
    await controller.markAllRead();
    expect(controller.unreadCount, 0);
    expect(controller.items.every((n) => n.read), isTrue);

    repository
      ..failMark = true
      ..page = NotificationPage(items: [_n('c')], unreadCount: 1);
    await controller.load();
    await controller.markAllRead();
    expect(controller.unreadCount, 1);
    expect(controller.items.single.read, isFalse);
    await controller.stop();
  });

  test(
    'A failed live connection keeps the REST list and retries later',
    () async {
      final realtime = _FakeRealtime()..failStart = true;
      final controller = NotificationController(
        _FakeRepository(NotificationPage(items: [_n('a')], unreadCount: 1)),
        realtime,
      );
      await controller.start();
      expect(controller.connected, isFalse);
      expect(controller.items.length, 1);
      await controller.stop();
    },
  );

  test('Parses both camelCase and PascalCase notification payloads', () {
    final camel = AppNotification.fromJson({
      'id': '1',
      'message': 'm',
      'complaintId': 'c',
      'read': false,
      'createdAt': '2026-11-19T10:00:00Z',
    });
    final pascal = AppNotification.fromJson({
      'Id': '2',
      'Message': 'm',
      'ComplaintId': 'c',
      'Read': true,
      'CreatedAt': '2026-11-19T10:00:00Z',
    });
    expect(camel.id, '1');
    expect(pascal.read, isTrue);
  });
}
