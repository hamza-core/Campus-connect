import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

final class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final skeleton = Column(
      children: List.generate(
        itemCount,
        (index) => Container(
          width: double.infinity,
          height: 56,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: colors.outline,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: MediaQuery.disableAnimationsOf(context)
          ? skeleton
          : Shimmer.fromColors(
              baseColor: colors.outline,
              highlightColor: colors.surface,
              child: skeleton,
            ),
    );
  }
}
