import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/widgets/entrance_motion.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../di/app_scope.dart';
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

final class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  StudentDashboardController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= StudentDashboardController(AppScope.of(context).complaints)
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
    final theme = Theme.of(context);
    return ResponsiveCenter(
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 76),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                  bottom: Radius.circular(28),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Text(
                        widget.user.name.characters.first.toUpperCase(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hi, ${widget.user.name.split(' ').first}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final changed = await context.push<bool>('/student/new');
                if (changed == true && mounted) await controller.load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Report an issue'),
            ),
            const SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }
}
