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

  int _insight = 0;

  static const _amber = Color(0xFFB45309);
  static const _blue = Color(0xFF1D4ED8);
  static const _red = Color(0xFFB91C1C);

  static String _hours(double? h) => h == null
      ? '—'
      : h < 48
      ? '${h.toStringAsFixed(1)} h'
      : '${(h / 24).toStringAsFixed(1)} d';

  Widget _stats(BuildContext context, AdminDashboardController controller) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (controller.state == ViewState.loading) return const ShimmerList();
          if (controller.state == ViewState.error) {
            return ErrorView(
              message: controller.errorMessage!,
              onRetry: controller.load,
            );
          }
          final stats = controller.stats;
          if (stats == null) return const SizedBox.shrink();
          void open(String query) =>
              context.go('${widget.complaintsPath}?$query');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Needs attention',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(widget.complaintsPath),
                    child: const Text('All complaints'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _Kpi(
                      label: 'Pending',
                      value: '${stats.pending}',
                      color: _amber,
                      icon: Icons.schedule_rounded,
                      onTap: () => open('status=PENDING'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Kpi(
                      label: 'In progress',
                      value: '${stats.inProgress}',
                      color: _blue,
                      icon: Icons.play_arrow_rounded,
                      onTap: () => open('status=IN_PROGRESS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Kpi(
                      label: 'Overdue',
                      value: '${stats.overdue}',
                      color: _red,
                      icon: Icons.warning_amber_rounded,
                      onTap: () => open('overdue=true'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Summary(
                items: [
                  ('Total', '${stats.total}'),
                  ('Resolved', '${stats.resolved}'),
                  ('Rejected', '${stats.rejected}'),
                  ('Avg. resolution', _hours(stats.avgResolutionHours)),
                  (
                    'Avg. rating',
                    stats.avgRating == null
                        ? '—'
                        : '${stats.avgRating!.toStringAsFixed(1)} / 5',
                  ),
                ],
              ),
            ],
          );
        },
      );

  Widget _insights(BuildContext context) {
    if (_chartsFailed && _byStatus == null) {
      return ErrorView(
        message: 'Could not load the charts.',
        onRetry: _refresh,
      );
    }
    if (_byStatus == null || _trend == null) return const ShimmerList();
    final tabs = <(String, Widget)>[
      ('Status', StatusDonutChart(stats: _byStatus!)),
      ('Trend', TrendLineChart(points: _trend!)),
      if (_recurring != null)
        ('Issues', RecurringIssuesCard(issues: _recurring!)),
      if (widget.showChart && _departments != null)
        ('Departments', DepartmentComplaintChart(departments: _departments!)),
    ];
    final index = _insight.clamp(0, tabs.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Insights',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < tabs.length; i++)
                ButtonSegment(value: i, label: Text(tabs[i].$1)),
            ],
            selected: {index},
            onSelectionChanged: (value) =>
                setState(() => _insight = value.single),
          ),
        ),
        const SizedBox(height: 12),
        tabs[index].$2,
      ],
    );
  }

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stats(context, controller),
                const SizedBox(height: 20),
                _insights(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One headline number that opens the matching, filtered complaint list.
final class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value. Opens the list.',
    excludeSemantics: true,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFCFC9B8), width: 1.5),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5F6B68),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Quiet secondary numbers, so they do not compete with the headline ones.
final class _Summary extends StatelessWidget {
  const _Summary({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        runSpacing: 12,
        children: [
          for (final (label, value) in items)
            FractionallySizedBox(
              widthFactor: .5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(label, style: const TextStyle(color: Color(0xFF5F6B68))),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
