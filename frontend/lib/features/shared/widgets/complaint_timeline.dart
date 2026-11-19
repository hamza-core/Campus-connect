import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
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

  String? _detail(TimelineEntry entry) {
    final body = entry.body?.trim();
    if (body != null && body.isNotEmpty) return body;
    if (entry.type == 'CREATED') return 'Sent to $departmentName';
    return entry.actorName;
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
                          color: theme.colorScheme.primary,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: theme.colorScheme.onPrimary,
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
                              DateFormatter.date(entries[i].createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
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
