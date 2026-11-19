import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';

final class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Access denied')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ErrorView(message: 'You do not have access to this page.'),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Go to dashboard'),
          ),
        ],
      ),
    ),
  );
}
