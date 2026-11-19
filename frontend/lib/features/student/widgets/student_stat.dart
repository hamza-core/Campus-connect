import 'package:flutter/material.dart';

import '../../../core/widgets/entrance_motion.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/illustration_image.dart';

final class StudentStat extends StatelessWidget {
  const StudentStat({
    super.key,
    required this.label,
    required this.value,
    required this.image,
    this.featured = false,
  });
  final String label;
  final int value;
  final String image;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // (background, foreground) per card; featured is the dark total card.
    final (background, foreground) = featured
        ? (theme.colorScheme.primary, theme.colorScheme.onPrimary)
        : switch (label) {
            'Pending' => (const Color(0xFFFBF0C5), const Color(0xFFB45309)),
            'In progress' => (const Color(0xFFDDE8FD), const Color(0xFF1D4ED8)),
            _ => (const Color(0xFFDDF6E4), const Color(0xFF15803D)),
          };
    final style = theme.textTheme.displaySmall?.copyWith(
      fontSize: featured ? 52 : 36,
      fontWeight: FontWeight.w800,
      color: foreground,
      height: 1,
    );
    final Widget number = MediaQuery.disableAnimationsOf(context)
        ? Text('$value', style: style)
        : Semantics(
            label: '$value',
            excludeSemantics: true,
            child: TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: value),
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOut,
              builder: (context, count, child) => Text('$count', style: style),
            ),
          );
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: featured ? foreground.withValues(alpha: .85) : foreground,
      fontWeight: featured ? FontWeight.w500 : FontWeight.w700,
    );
    return EntranceMotion(
      index: switch (label) {
        'Pending' => 1,
        'In progress' => 2,
        'Resolved' => 3,
        _ => 0,
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(featured ? 28 : 24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(featured ? 20 : 14),
          child: featured
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: labelStyle),
                          const SizedBox(height: 6),
                          number,
                        ],
                      ),
                    ),
                    CircleBadge(
                      size: 96,
                      child: IllustrationImage(filename: image, size: 96),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IllustrationImage(filename: image, size: 44),
                    const SizedBox(height: 8),
                    number,
                    const SizedBox(height: 4),
                    Text(label, style: labelStyle),
                  ],
                ),
        ),
      ),
    );
  }
}
