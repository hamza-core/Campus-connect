import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../di/app_scope.dart';
import '../controllers/admin_dashboard_controller.dart';

final class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.title,
    required this.complaintsPath,
  });
  final String title;
  final String complaintsPath;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

final class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboardController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= AdminDashboardController(AppScope.of(context).dashboard)
      ..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.title, style: textTheme.headlineMedium),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => context.go(widget.complaintsPath),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('View complaints'),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              if (controller.state == ViewState.loading) {
                return const ShimmerList();
              }
              if (controller.state == ViewState.error) {
                return ErrorView(
                  message: controller.errorMessage!,
                  onRetry: controller.load,
                );
              }
              final stats = controller.stats;
              if (stats == null) return const SizedBox.shrink();
              final values = [
                ('Total complaints', stats.total),
                ('Pending', stats.pending),
                ('In progress', stats.inProgress),
                ('Resolved', stats.resolved),
                ('Rejected', stats.rejected),
              ];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 850
                      ? 5
                      : constraints.maxWidth >= 480
                      ? 3
                      : 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final (label, count) in values)
                        SizedBox(
                          width:
                              (constraints.maxWidth - (columns - 1) * 10) /
                              columns,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$count',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(label),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
