import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A tab destination (Home, Complaints, Profile, the admin dashboard and
/// list). Tabs swap instantly, like any bottom navigation bar: a fade would
/// leave the old screen visible underneath the new one while it blends in.
Page<Object?> tabPage(GoRouterState state, Widget child) =>
    NoTransitionPage<Object?>(key: state.pageKey, child: child);

/// A page pushed on top of another (a complaint, the new-complaint form).
/// Uses the platform transition, where the old and new pages move together
/// instead of blending.
Page<Object?> pushedPage(GoRouterState state, Widget child) =>
    MaterialPage<Object?>(key: state.pageKey, child: child);
