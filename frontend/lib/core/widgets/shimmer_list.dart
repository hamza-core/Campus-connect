import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Loading placeholder. Shows as many rows as the space allows (at least one)
/// and clips the rest, so it never overflows a short area.
final class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.itemCount = 3});

  final int itemCount;

  static const _rowHeight = 56.0;
  static const _rowGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight;
          final rows = bounded
              ? (constraints.maxHeight / (_rowHeight + _rowGap)).floor().clamp(
                  1,
                  itemCount,
                )
              : itemCount;
          Widget skeleton = Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              rows,
              (index) => Container(
                width: double.infinity,
                height: _rowHeight,
                margin: const EdgeInsets.only(bottom: _rowGap),
                decoration: BoxDecoration(
                  color: colors.outline,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
          if (bounded) {
            skeleton = ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: skeleton,
              ),
            );
          }
          return MediaQuery.disableAnimationsOf(context)
              ? skeleton
              : Shimmer.fromColors(
                  baseColor: colors.outline,
                  highlightColor: colors.surface,
                  child: skeleton,
                );
        },
      ),
    );
  }
}
