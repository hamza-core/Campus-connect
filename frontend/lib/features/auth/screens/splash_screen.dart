import 'package:flutter/material.dart';

import '../../../core/widgets/hero_header.dart';

final class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: palette.primary,
      body: HeroHeader(
        bottomRadius: 0,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(scale: .92 + value * .08, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .10),
                      ),
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: const Color(0xFFF0EDE4),
                        foregroundColor: palette.primary,
                        child: const Text(
                          'CC',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CampusConnect',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: palette.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your voice, heard on campus',
                    style: TextStyle(
                      color: palette.onPrimary.withValues(alpha: .85),
                    ),
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
