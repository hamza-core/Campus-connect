import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/recurring_issue.dart';
import 'complaint_tile.dart';

/// Most frequent problems on campus (by category and issue), with bars.
final class RecurringIssuesCard extends StatelessWidget {
  const RecurringIssuesCard({super.key, required this.issues});
  final List<RecurringIssue> issues;

  @override
  Widget build(BuildContext context) {
    final maximum = issues.fold<int>(0, (m, i) => i.count > m ? i.count : m);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recurring issues',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The problems students report most often.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 14),
            if (issues.isEmpty) const Text('No recurring issues yet.'),
            for (final issue in issues.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  label:
                      '${issue.category.label}, ${issue.subIssue}, ${issue.count} complaints',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            issue.category.icon,
                            size: 18,
                            color: issue.category.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue.subIssue,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${issue.count}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: maximum == 0 ? 0 : issue.count / maximum,
                          minHeight: 8,
                          color: issue.category.color,
                          backgroundColor: issue.category.color.withValues(
                            alpha: .15,
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
    );
  }
}
