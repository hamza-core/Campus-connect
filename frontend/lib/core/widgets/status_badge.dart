import 'package:flutter/material.dart';

import '../../domain/enums/complaint_status.dart';

final class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      ComplaintStatus.pending => ('Pending', 0xFFB45309, 0xFFFDF0C4),
      ComplaintStatus.inProgress => ('In-Progress', 0xFF1D4ED8, 0xFFDBE7FD),
      ComplaintStatus.resolved => ('Resolved', 0xFF15803D, 0xFFDDF6E4),
      ComplaintStatus.rejected => ('Rejected', 0xFFB91C1C, 0xFFFDE0E0),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(background),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(foreground).withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(foreground),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Color(foreground),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
