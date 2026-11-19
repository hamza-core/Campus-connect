import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/models/complaint_summary.dart';

extension CategoryLabel on ComplaintCategory {
  String get label => switch (this) {
    ComplaintCategory.cafeteria => 'Cafeteria',
    ComplaintCategory.library => 'Library',
    ComplaintCategory.labsAndIt => 'Labs & IT',
    ComplaintCategory.academic => 'Teaching & Academic',
  };
}

final class ComplaintTile extends StatelessWidget {
  const ComplaintTile({super.key, required this.item, required this.onTap});
  final ComplaintSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${item.ticket} · ${DateFormatter.date(item.createdAt)}'),
            StatusBadge(status: item.status),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
