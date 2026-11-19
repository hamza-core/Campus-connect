import 'package:flutter/material.dart';

import '../../domain/enums/complaint_status.dart';

final class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      ComplaintStatus.pending => ('Pending', 0xFFB45309, 0xFFFEF3C7),
      ComplaintStatus.inProgress => ('In progress', 0xFF1D4ED8, 0xFFDBEAFE),
      ComplaintStatus.resolved => ('Resolved', 0xFF15803D, 0xFFDCFCE7),
      ComplaintStatus.rejected => ('Rejected', 0xFFB91C1C, 0xFFFEE2E2),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(background),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Color(foreground)),
        ),
      ),
    );
  }
}
