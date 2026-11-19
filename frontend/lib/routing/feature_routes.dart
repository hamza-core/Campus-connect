import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/shared/screens/complaint_detail_screen.dart';
import '../features/shared/screens/complaint_list_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/student_profile_screen.dart';
import '../features/student/screens/submit_complaint_screen.dart';
import '../features/student/widgets/student_shell.dart';

List<RouteBase> featureRoutes(AuthController auth) => [
  ShellRoute(
    builder: (context, state, child) =>
        StudentShell(route: state.uri.path, child: child),
    routes: [
      GoRoute(
        path: '/student',
        builder: (context, state) => StudentDashboardScreen(user: auth.user!),
      ),
      GoRoute(
        path: '/student/complaints',
        builder: (context, state) => ComplaintListScreen(
          key: ValueKey(state.uri.toString()),
          basePath: '/student/complaints',
          title: 'My complaints',
          student: true,
        ),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (context, state) => StudentProfileScreen(auth: auth),
      ),
    ],
  ),
  GoRoute(
    path: '/student/new',
    builder: (context, state) => SubmitComplaintScreen(ownerId: auth.user!.id),
  ),
  GoRoute(
    path: '/student/complaints/:id',
    builder: (context, state) => ComplaintDetailScreen(
      key: ValueKey(state.pathParameters['id']),
      id: state.pathParameters['id']!,
      backPath: '/student/complaints',
      photoOwnerId: auth.user!.id,
    ),
  ),
  for (final path in ['/department', '/admin'])
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
