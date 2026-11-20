import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/enums/user_role.dart';
import '../../../domain/models/timeline_entry.dart';

/// Vertical timeline: dot + connecting line, bold step, date and detail text.
final class ComplaintTimeline extends StatelessWidget {
  const ComplaintTimeline({
    super.key,
    required this.entries,
    required this.departmentName,
  });
  final List<TimelineEntry> entries;
  final String departmentName;

  String _title(TimelineEntry entry) =>
      entry.toStatus?.label ??
      switch (entry.type) {
        'REMARK' => 'Remark added',
        'STUDENT_REPLY' => 'Reply sent',
        _ => 'Submitted',
      };

  static Color _color(TimelineEntry entry, Color fallback) =>
      switch (entry.toStatus) {
        ComplaintStatus.pending => const Color(0xFFB45309),
        ComplaintStatus.inProgress => const Color(0xFF1D4ED8),
        ComplaintStatus.resolved => const Color(0xFF15803D),
        ComplaintStatus.rejected => const Color(0xFFB91C1C),
        null =>
          entry.type == 'REMARK' || entry.type == 'STUDENT_REPLY'
              ? const Color(0xFF5F6B68)
              : fallback,
      };

  static IconData _icon(TimelineEntry entry) => switch (entry.toStatus) {
    ComplaintStatus.resolved => Icons.check_rounded,
    ComplaintStatus.rejected => Icons.close_rounded,
    ComplaintStatus.inProgress => Icons.play_arrow_rounded,
    ComplaintStatus.pending => Icons.schedule_rounded,
    null => Icons.chat_bubble_outline_rounded,
  };

  static String? _by(TimelineEntry entry) {
    final name = entry.actorName;
    if (name == null) return null;
    final role = switch (entry.actorRole) {
      UserRole.student => 'Student',
      UserRole.departmentAdmin => 'Department admin',
      UserRole.superAdmin => 'Super admin',
      null => null,
    };
    return role == null ? name : '$name · $role';
  }

  String? _detail(TimelineEntry entry) {
    final body = entry.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    if (entry.type == 'CREATED') return 'Sent to $departmentName';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _color(entries[i], theme.colorScheme.primary),
                        ),
                        child: Icon(
                          entries[i].type == 'CREATED'
                              ? Icons.check
                              : _icon(entries[i]),
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (i != entries.length - 1)
                        Expanded(
                          child: Container(
                            width: 2.5,
                            color: theme.colorScheme.primary.withValues(
                              alpha: .35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              _title(entries[i]),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${DateFormatter.date(entries[i].createdAt)}, ${DateFormat.jm().format(entries[i].createdAt.toLocal())}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        if (_by(entries[i]) case final by?)
                          Text(
                            by,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        if (_detail(entries[i]) case final detail?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              detail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tinted reply block with an accent bar ("Response from the department").
final class DepartmentReply extends StatelessWidget {
  const DepartmentReply({
    super.key,
    required this.departmentName,
    required this.message,
  });
  final String departmentName;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3ECE9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .25),
          width: 1.5,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Response from $departmentName',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
