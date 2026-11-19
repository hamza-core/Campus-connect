import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';

List<RouteBase> featureRoutes(AuthController auth) => [
  for (final path in ['/student', '/department', '/admin'])
    GoRoute(
      path: path,
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('CampusConnect')),
        body: Center(
          child: TextButton(
            onPressed: auth.signOut,
            child: const Text('Log out'),
          ),
        ),
      ),
    ),
];
