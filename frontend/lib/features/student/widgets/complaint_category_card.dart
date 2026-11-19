import 'package:flutter/material.dart';

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
    final (filename, background) = switch (item) {
      ComplaintCategory.cafeteria => ('cafeteria.jpg', const Color(0xFFFCEBD3)),
      ComplaintCategory.library => ('library.jpg', const Color(0xFFE9E6FD)),
      ComplaintCategory.labsAndIt => ('labs-it.jpg', const Color(0xFFD5F6FC)),
      ComplaintCategory.academic => (
        'teaching-academic.jpg',
        const Color(0xFFD9F6E3),
      ),
    };
    return Semantics(
      button: true,
      label: item.label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        elevation: 3,
        shadowColor: const Color(0x33000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 170),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IllustrationImage(filename: filename, size: 84),
                  const SizedBox(height: 18),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
