import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../di/app_scope.dart';
import '../../../domain/models/department_stat.dart';
import '../../../domain/models/status_stat.dart';
import '../../../domain/models/trend_point.dart';
import '../../shared/widgets/dashboard_charts.dart';
import '../../super_admin/widgets/department_complaint_chart.dart';
import '../controllers/admin_dashboard_controller.dart';

final class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.title,
    required this.complaintsPath,
    this.showChart = false,
  });
  final String title;
  final String complaintsPath;
  final bool showChart;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

final class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminDashboardController? _controller;
  Future<List<DepartmentStat>>? _departments;
  Future<List<StatusStat>>? _byStatus;
  Future<List<TrendPoint>>? _trend;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= AdminDashboardController(AppScope.of(context).dashboard)
      ..load();
    if (widget.showChart) {
      _departments ??= AppScope.of(context).dashboard.byDepartment();
    }
    final dashboard = AppScope.of(context).dashboard;
    _byStatus ??= dashboard.byStatus();
    _trend ??= dashboard.trend();
  }

  Future<void> _refresh() async {
    final dashboard = AppScope.of(context).dashboard;
    setState(() {
      _byStatus = dashboard.byStatus();
      _trend = dashboard.trend();
    });
    if (widget.showChart) {
      final request = AppScope.of(context).dashboard.byDepartment();
      setState(() => _departments = request);
    }
    await _controller!.load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  (Color, Color) _tint(String label) => switch (label) {
    'Pending' => (const Color(0xFFFBF0C5), const Color(0xFFB45309)),
    'In progress' => (const Color(0xFFDDE8FD), const Color(0xFF1D4ED8)),
    'Resolved' => (const Color(0xFFDDF6E4), const Color(0xFF15803D)),
    'Rejected' => (const Color(0xFFFDE0E0), const Color(0xFFB91C1C)),
    _ => (
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.onPrimary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final textTheme = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          HeroHeader(
            bottomRadius: 32,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.showChart ? 'Super admin' : 'Department admin',
                  style: textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary
                        .withValues(alpha: .8),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                    (constraints.maxWidth -
                                        (columns - 1) * 10) /
                                    columns,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: _tint(label).$1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$count',
                                          style: textTheme.headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: _tint(label).$2,
                                              ),
                                        ),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            color: _tint(label).$2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
                const SizedBox(height: 16),
                FutureBuilder<List<StatusStat>>(
                  future: _byStatus,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ShimmerList();
                    }
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Could not load the status chart.',
                        onRetry: _refresh,
                      );
                    }
                    return StatusDonutChart(stats: snapshot.data ?? const []);
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<TrendPoint>>(
                  future: _trend,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ShimmerList();
                    }
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Could not load the trend chart.',
                        onRetry: _refresh,
                      );
                    }
                    return TrendLineChart(points: snapshot.data ?? const []);
                  },
                ),
                if (widget.showChart) ...[
                  const SizedBox(height: 16),
                  FutureBuilder<List<DepartmentStat>>(
                    future: _departments,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ShimmerList();
                      }
                      if (snapshot.hasError) {
                        return ErrorView(
                          message:
                              'Could not load department complaint counts.',
                          onRetry: _refresh,
                        );
                      }
                      return DepartmentComplaintChart(
                        departments: snapshot.data ?? const [],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
