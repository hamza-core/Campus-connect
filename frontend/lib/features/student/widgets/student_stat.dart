import 'package:flutter/material.dart';

import '../../../core/widgets/clay_card.dart';
import '../../../core/widgets/entrance_motion.dart';
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
    final style = Theme.of(context).textTheme.headlineMedium
        ?.copyWith(fontSize: featured ? 44 : null, fontWeight: FontWeight.w700);
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
    return EntranceMotion(
      index: switch (label) {
        'Pending' => 1,
        'In progress' => 2,
        'Resolved' => 3,
        _ => 0,
      },
      child: SizedBox(
        width: featured ? null : 98,
        child: ClayCard(
          padding: EdgeInsets.all(featured ? 16 : 10),
          child: featured
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(label), number],
                      ),
                    ),
                    IllustrationImage(filename: image, size: 68),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IllustrationImage(filename: image, size: 38),
                    number,
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}
