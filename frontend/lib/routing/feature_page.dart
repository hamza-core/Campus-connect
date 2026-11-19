import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Page<Object?> featurePage(
  GoRouterState state,
  Widget child, {
  bool studentMotion = false,
}) => CustomTransitionPage<Object?>(
  key: state.pageKey,
  child: child,
  transitionDuration: Duration(milliseconds: studentMotion ? 360 : 150),
  reverseTransitionDuration: const Duration(milliseconds: 150),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curve,
      child: studentMotion
          ? SlideTransition(
              position: curve.drive(
                Tween(begin: const Offset(0, .025), end: Offset.zero),
              ),
              child: child,
            )
          : child,
    );
  },
);
