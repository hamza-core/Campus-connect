import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../domain/models/complaint.dart';
import 'complaint_tile.dart';

/// Ticket, category, priority, location and due date of a complaint.
final class ComplaintDetailsCard extends StatelessWidget {
  const ComplaintDetailsCard({super.key, required this.complaint});
  final Complaint complaint;

  @override
  Widget build(BuildContext context) {
    final summary = complaint.summary;
    final due = complaint.dueAt;
    final open = !{'RESOLVED', 'REJECTED'}.contains(summary.status.apiValue);
    final rows = <(String, Widget)>[
      ('Ticket', Text(summary.ticket, style: _value)),
      (
        'Category',
        Text(
          complaint.subIssue == null
              ? summary.category.label
              : '${summary.category.label} · ${complaint.subIssue}',
          style: _value,
        ),
      ),
      (
        'Priority',
        Align(
          alignment: Alignment.centerLeft,
          child: PriorityBadge(priority: summary.priority),
        ),
      ),
      if (complaint.location case final place? when place.isNotEmpty)
        ('Location', Text(place, style: _value)),
      if (due != null)
        (
          open ? 'Response due' : 'Was due',
          Text(
            DateFormatter.date(due),
            style: _value.copyWith(
              color: open && complaint.isOverdue
                  ? const Color(0xFFB42318)
                  : null,
            ),
          ),
        ),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    label,
                    style: const TextStyle(color: AppColors.secondaryText),
                  ),
                ),
                Expanded(child: value),
              ],
            ),
          ),
      ],
    );
  }

  static const _value = TextStyle(fontWeight: FontWeight.w700);
}
