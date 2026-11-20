import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/assistant/widgets/chat_fab.dart';
import 'features/auth/controllers/auth_controller.dart';

final class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({
    super.key,
    required this.router,
    this.theme,
    this.auth,
  });

  final GoRouter router;
  final ThemeData? theme;

  /// When set, a floating chat button is shown on every signed-in screen.
  final AuthController? auth;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'CampusConnect',
    routerConfig: router,
    theme: theme,
    builder: (context, child) {
      final session = auth;
      if (session == null || child == null) return child ?? const SizedBox();
      return Stack(
        children: [
          child,
          ListenableBuilder(
            listenable: Listenable.merge([session, router.routerDelegate]),
            builder: (context, _) {
              final path = router.routeInformationProvider.value.uri.path;
              if (session.user == null || path == '/assistant') {
                return const SizedBox.shrink();
              }
              return Positioned(
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 96,
                child: ChatFab(onPressed: () => router.push('/assistant')),
              );
            },
          ),
        ],
      );
    },
  );
}
