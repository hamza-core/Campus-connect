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

  static const _amber = Color(0xFFB45309);
  static const _blue = Color(0xFF1D4ED8);
  static const _red = Color(0xFFB91C1C);
  static const _green = Color(0xFF15803D);

  static String _hours(double? h) => h == null
      ? '—'
      : h < 48
      ? '${h.toStringAsFixed(1)} h'
      : '${(h / 24).toStringAsFixed(1)} d';

  void _open(String query) => context.go('${widget.complaintsPath}?$query');

  /// Dark header: who and where, one status line, and the four numbers that
  /// matter, each opening the matching filtered list.
  Widget _hero(BuildContext context, AdminDashboardController controller) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          final theme = Theme.of(context);
          final onPrimary = theme.colorScheme.onPrimary;
          final stats = controller.stats;
          final open = stats == null ? 0 : stats.pending + stats.inProgress;
          final line = stats == null
              ? (controller.state == ViewState.error ? '' : 'Loading…')
              : open == 0 && stats.overdue == 0
              ? 'Everything is under control'
              : '$open open · ${stats.overdue} overdue';
          return HeroHeader(
            bottomRadius: 32,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (widget.showChart ? 'Super admin' : 'Department admin')
                      .toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onPrimary.withValues(alpha: .75),
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (line.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: onPrimary.withValues(alpha: .85),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (stats == null)
                  const _KpiPlaceholder()
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _Kpi(
                          label: 'Pending',
                          value: stats.pending,
                          color: _amber,
                          icon: Icons.schedule_rounded,
                          onTap: () => _open('status=PENDING'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Kpi(
                          label: 'In progress',
                          value: stats.inProgress,
                          color: _blue,
                          icon: Icons.autorenew_rounded,
                          onTap: () => _open('status=IN_PROGRESS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Kpi(
                          label: 'Overdue',
                          value: stats.overdue,
                          color: _red,
                          icon: Icons.warning_amber_rounded,
                          alert: stats.overdue > 0,
                          onTap: () => _open('overdue=true'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Kpi(
                          label: 'Resolved',
                          value: stats.resolved,
                          color: _green,
                          icon: Icons.check_circle_outline_rounded,
                          onTap: () => _open('status=RESOLVED'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );

  Widget _overview(
    BuildContext context,
    AdminDashboardController controller,
  ) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      final stats = controller.stats;
      if (stats == null) {
        return controller.state == ViewState.error
            ? ErrorView(
                message: controller.errorMessage!,
                onRetry: controller.load,
              )
            : const SizedBox.shrink();
      }
      final theme = Theme.of(context);
      final rate = stats.total == 0 ? 0.0 : stats.resolved / stats.total;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.go(widget.complaintsPath),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                iconAlignment: IconAlignment.end,
                label: const Text('All complaints'),
              ),
            ],
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RateRing(value: rate),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resolution rate',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stats.resolved} of ${stats.total} complaints resolved'
                              '${stats.rejected > 0 ? ' · ${stats.rejected} rejected' : ''}',
                              style: const TextStyle(
                                color: Color(0xFF5F6B68),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Total',
                          child: Text('${stats.total}'),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Avg. resolution',
                          child: Text(_hours(stats.avgResolutionHours)),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Avg. rating',
                          child: stats.avgRating == null
                              ? const Text('—')
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(stats.avgRating!.toStringAsFixed(1)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Insights',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TrendLineChart(points: _trend!),
        const SizedBox(height: 12),
        StatusDonutChart(stats: _byStatus!),
        if (_recurring != null) ...[
          const SizedBox(height: 12),
          RecurringIssuesCard(issues: _recurring!),
        ],
        if (widget.showChart && _departments != null) ...[
          const SizedBox(height: 12),
          DepartmentComplaintChart(departments: _departments!),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _hero(context, controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _overview(context, controller),
                const SizedBox(height: 16),
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
    this.alert = false,
  });
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  /// Draws attention (a red outline) when something needs action now.
  final bool alert;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value. Opens the list.',
    excludeSemantics: true,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: alert
            ? BorderSide(color: color.withValues(alpha: .55), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 2),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Same footprint as the real tiles, so nothing jumps when numbers arrive.
final class _KpiPlaceholder extends StatelessWidget {
  const _KpiPlaceholder();

  @override
  Widget build(BuildContext context) {
    Widget box() => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(height: 70),
      ),
    );
    return Column(
      children: [
        Row(children: [box(), const SizedBox(width: 10), box()]),
        const SizedBox(height: 10),
        Row(children: [box(), const SizedBox(width: 10), box()]),
      ],
    );
  }
}

/// Circular progress with the percentage in the middle.
final class _RateRing extends StatelessWidget {
  const _RateRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Semantics(
      label: '$percent percent resolved',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFE4E0D3),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small labelled number under the overview.
final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
        child: child,
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF5F6B68), fontSize: 12.5),
      ),
    ],
  );
}
