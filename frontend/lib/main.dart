import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

void main() {
  final router = AppRouter.create(
    home: (context) =>
        const Scaffold(body: Center(child: Text('CampusConnect'))),
  );
  runApp(CampusConnectApp(router: router, theme: AppTheme.student()));
}
