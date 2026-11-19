import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/clay_card.dart';
import '../../../core/widgets/illustration_image.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../shared/widgets/complaint_tile.dart';

final class ComplaintCategoryCard extends StatelessWidget {
  const ComplaintCategoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });
  final ComplaintCategory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (filename, color) = switch (item) {
      ComplaintCategory.cafeteria => ('cafeteria.jpg', AppColors.cafeteria),
      ComplaintCategory.library => ('library.jpg', AppColors.library),
      ComplaintCategory.labsAndIt => ('labs-it.jpg', AppColors.labsAndIt),
      ComplaintCategory.academic => (
        'teaching-academic.jpg',
        AppColors.academic,
      ),
    };
    return ClayCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IllustrationImage(filename: filename, size: 62),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
