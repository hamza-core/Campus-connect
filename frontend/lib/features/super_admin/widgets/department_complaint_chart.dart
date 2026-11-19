import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../domain/models/department_stat.dart';

final class DepartmentComplaintChart extends StatelessWidget {
  const DepartmentComplaintChart({super.key, required this.departments});
  final List<DepartmentStat> departments;

  @override
  Widget build(BuildContext context) {
    final maximum = departments.fold<int>(
      0,
      (value, item) => item.count > value ? item.count : value,
    );
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Complaints by department', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (departments.isEmpty) const Text('No departments to display.'),
            for (final item in departments)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  label: '${item.department.name}, ${item.count} complaints',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.department.name)),
                          const SizedBox(width: 8),
                          Text(
                            '${item.count}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: maximum == 0 ? 0 : item.count / maximum,
                        color: AdminColors.accent,
                        backgroundColor: AdminColors.background,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(3),
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
