import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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

  Color get color => switch (this) {
    ComplaintCategory.cafeteria => AppColors.cafeteria,
    ComplaintCategory.library => AppColors.library,
    ComplaintCategory.labsAndIt => AppColors.labsAndIt,
    ComplaintCategory.academic => AppColors.academic,
  };

  IconData get icon => switch (this) {
    ComplaintCategory.cafeteria => Icons.restaurant,
    ComplaintCategory.library => Icons.menu_book_outlined,
    ComplaintCategory.labsAndIt => Icons.desktop_windows_outlined,
    ComplaintCategory.academic => Icons.school_outlined,
  };
}

String timeAgo(DateTime timestamp) {
  final diff = DateTime.now().difference(timestamp.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 14) return '${diff.inDays}d ago';
  if (diff.inDays < 60) return '${diff.inDays ~/ 7}w ago';
  return '${diff.inDays ~/ 30}mo ago';
}

final class ComplaintTile extends StatelessWidget {
  const ComplaintTile({super.key, required this.item, required this.onTap});
  final ComplaintSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.category.color.withValues(alpha: .16),
                  border: Border.all(
                    color: item.category.color.withValues(alpha: .45),
                    width: 1.5,
                  ),
                ),
                child: Icon(item.category.icon, color: item.category.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.ticket} · ${timeAgo(item.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(status: item.status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
