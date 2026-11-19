import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/auto_refresh.dart';
import '../../../core/widgets/entrance_motion.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/hero_header.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../di/app_scope.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../../domain/models/app_user.dart';
import '../../shared/widgets/complaint_tile.dart';
import '../controllers/student_dashboard_controller.dart';
import '../widgets/student_stat.dart';

final class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

final class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with WidgetsBindingObserver {
  StudentDashboardController? _controller;
  Timer? _autoRefresh;
  Listenable? _live;

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
    _controller ??= StudentDashboardController(AppScope.of(context).complaints)
      ..load();
    _live ??= AppScope.of(context).notifications..addListener(_checkForUpdates);
  }

  void _checkForUpdates() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _controller?.refreshSilently();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    _live?.removeListener(_checkForUpdates);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final theme = Theme.of(context);
    return ResponsiveCenter(
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                final stats = controller.stats;
                final open = stats == null
                    ? 0
                    : stats.pending + stats.inProgress;
                return HeroHeader(
                  bottomRadius: 36,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFD3E3DE),
                            foregroundColor: theme.colorScheme.primary,
                            child: Text(
                              widget.user.name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          NotificationBell(
                            controller: AppScope.of(context).notifications,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Hi, ${widget.user.name.split(' ').first}',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stats == null
                            ? 'Loading your complaints…'
                            : open == 0
                            ? 'You are all caught up'
                            : '$open complaint${open == 1 ? '' : 's'} need attention',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: .85,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListenableBuilder(
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StudentStat(
                        label: 'Total complaints',
                        value: stats.total,
                        image: 'total-complaints.jpg',
                        featured: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          StudentStat(
                            label: 'Pending',
                            value: stats.pending,
                            image: 'pending.jpg',
                          ),
                          StudentStat(
                            label: 'In progress',
                            value: stats.inProgress,
                            image: 'in-progress.jpg',
                          ),
                          StudentStat(
                            label: 'Resolved',
                            value: stats.resolved,
                            image: 'resolved.jpg',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Recent complaints',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (controller.recent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Your submitted complaints will appear here.',
                          ),
                        ),
                      for (final (index, item) in controller.recent.indexed)
                        EntranceMotion(
                          index: index,
                          child: ComplaintTile(
                            item: item,
                            onTap: () => context.push(
                              '/student/complaints/${Uri.encodeComponent(item.id)}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
