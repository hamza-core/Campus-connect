import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/shared/screens/not_found_screen.dart';

final class AppRouter {
  const AppRouter._();

  static GoRouter create({required WidgetBuilder home}) => GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => home(context))],
    errorBuilder: (context, state) =>
        NotFoundScreen(onGoHome: () => context.go('/')),
  );
}
