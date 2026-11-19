import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/notification_controller.dart';

/// Bell with an unread badge; opens the notifications screen.
final class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.controller});
  final NotificationController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final count = controller.unreadCount;
      return Semantics(
        button: true,
        label: count == 0 ? 'Notifications' : 'Notifications, $count unread',
        excludeSemantics: true,
        child: Material(
          color: Colors.white.withValues(alpha: .12),
          shape: const CircleBorder(),
          child: InkResponse(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/student/notifications'),
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 9 ? '9+' : '$count'),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFFF0EDE4),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
