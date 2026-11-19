import 'package:flutter/material.dart';

final class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Page not found'),
          TextButton(onPressed: onGoHome, child: const Text('Go home')),
        ],
      ),
    ),
  );
}
