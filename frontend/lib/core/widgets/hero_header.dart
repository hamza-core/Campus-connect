import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dark-green hero area with a dot pattern and soft circles, as in the
/// CampusConnect mobile UI design. Extends under the status bar.
final class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 28),
    this.bottomRadius = 32,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _HeroPainter(primary))),
            Padding(
              padding: EdgeInsets.only(top: top),
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

final class _HeroPainter extends CustomPainter {
  const _HeroPainter(this.base);
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final soft = Paint()..color = Colors.white.withValues(alpha: .09);
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .05),
      size.width * .32,
      soft,
    );
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .98),
      size.width * .16,
      soft,
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: .10);
    for (var y = 12.0; y < size.height; y += 22) {
      for (var x = 12.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) => oldDelegate.base != base;
}

/// Round, light badge holding an illustration (login / dashboard heroes).
final class CircleBadge extends StatelessWidget {
  const CircleBadge({super.key, required this.size, required this.child});
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFD3E3DE),
    ),
    clipBehavior: Clip.antiAlias,
    child: Center(child: child),
  );
}
