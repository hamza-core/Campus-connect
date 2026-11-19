import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/auto_refresh.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../di/app_scope.dart';
import '../../../domain/models/department_stat.dart';
import '../../../domain/models/status_stat.dart';
import '../../../domain/models/trend_point.dart';
import '../../../domain/models/recurring_issue.dart';
import '../../shared/widgets/dashboard_charts.dart';
import '../../shared/widgets/recurring_issues_card.dart';
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

final class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with WidgetsBindingObserver {
  AdminDashboardController? _controller;
  Timer? _autoRefresh;
  List<DepartmentStat>? _departments;
  List<StatusStat>? _byStatus;
  List<TrendPoint>? _trend;
  List<RecurringIssue>? _recurring;
  bool _chartsFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoRefresh = Timer.periodic(
      autoRefreshInterval,
      (_) => _checkForUpdates(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = AdminDashboardController(AppScope.of(context).dashboard)
        ..load();
      _loadCharts();
    }
  }

  /// Fetches all charts together and swaps them in only when they arrive, so
  /// refreshing never flashes a loading placeholder over data already shown.
  Future<void> _loadCharts() async {
    final dashboard = AppScope.of(context).dashboard;
    try {
      final status = await dashboard.byStatus();
      final trend = await dashboard.trend();
      final recurring = await dashboard.recurring();
      final departments = widget.showChart
          ? await dashboard.byDepartment()
          : null;
      if (!mounted) return;
      setState(() {
        _byStatus = status;
        _trend = trend;
        _recurring = recurring;
        _departments = departments;
        _chartsFailed = false;
      });
    } on Object {
      if (mounted && _byStatus == null) setState(() => _chartsFailed = true);
    }
  }

  void _checkForUpdates() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _controller?.refreshSilently();
    _loadCharts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForUpdates();
  }

  Future<void> _refresh() async {
    setState(() => _chartsFailed = false);
    await Future.wait([_controller!.load(), _loadCharts()]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  (Color, Color) _tint(String label) => switch (label) {
    'Pending' => (const Color(0xFFFBF0C5), const Color(0xFFB45309)),
    'In progress' => (const Color(0xFFDDE8FD), const Color(0xFF1D4ED8)),
    'Resolved' => (const Color(0xFFDDF6E4), const Color(0xFF15803D)),
    'Rejected' => (const Color(0xFFFDE0E0), const Color(0xFFB91C1C)),
    'Overdue' => (const Color(0xFFFDE0E0), const Color(0xFFB42318)),
    'Avg. resolution' => (const Color(0xFFE3ECE9), const Color(0xFF004741)),
    'Avg. rating' => (const Color(0xFFFBF0C5), const Color(0xFF8A5A00)),
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
                    String hours(double? h) => h == null
                        ? '—'
                        : h < 48
                        ? '${h.toStringAsFixed(1)} h'
                        : '${(h / 24).toStringAsFixed(1)} d';
                    final values = [
                      ('Total complaints', '${stats.total}'),
                      ('Pending', '${stats.pending}'),
                      ('In progress', '${stats.inProgress}'),
                      ('Resolved', '${stats.resolved}'),
                      ('Rejected', '${stats.rejected}'),
                      ('Overdue', '${stats.overdue}'),
                      ('Avg. resolution', hours(stats.avgResolutionHours)),
                      (
                        'Avg. rating',
                        stats.avgRating == null
                            ? '—'
                            : '${stats.avgRating!.toStringAsFixed(1)} / 5',
                      ),
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
                            for (final (label, shown) in values)
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
                                          shown,
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
                if (_chartsFailed && _byStatus == null)
                  ErrorView(
                    message: 'Could not load the charts.',
                    onRetry: _refresh,
                  )
                else if (_byStatus == null || _trend == null)
                  const ShimmerList()
                else ...[
                  StatusDonutChart(stats: _byStatus!),
                  const SizedBox(height: 16),
                  TrendLineChart(points: _trend!),
                  if (_recurring != null) ...[
                    const SizedBox(height: 16),
                    RecurringIssuesCard(issues: _recurring!),
                  ],
                  if (widget.showChart && _departments != null) ...[
                    const SizedBox(height: 16),
                    DepartmentComplaintChart(departments: _departments!),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
