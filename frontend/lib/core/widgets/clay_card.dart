import 'package:flutter/material.dart';

import '../theme/clay_style.dart';

final class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ClayStyle.decoration(Theme.of(context).colorScheme.surface),
    child: Padding(padding: padding, child: child),
  );
}
