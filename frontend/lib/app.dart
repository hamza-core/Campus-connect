import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final class CampusConnectApp extends StatelessWidget {
  const CampusConnectApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(title: 'CampusConnect', routerConfig: router);
}
