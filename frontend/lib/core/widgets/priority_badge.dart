import 'package:flutter/material.dart';

import '../../domain/enums/priority.dart';

final class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (priority) {
      Priority.high => (const Color(0xFFB42318), const Color(0xFFFDE8E6)),
      Priority.medium => (const Color(0xFF475467), const Color(0xFFEDEFF2)),
      Priority.low => (const Color(0xFF3B7A57), const Color(0xFFE6F3EC)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: foreground.withValues(alpha: .3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 13, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${priority.label} priority',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class OverdueBadge extends StatelessWidget {
  const OverdueBadge({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFB42318),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Overdue',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
