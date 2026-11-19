import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../di/app_scope.dart';
import '../../shared/widgets/complaint_tile.dart';
import '../controllers/notification_controller.dart';

final class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).notifications;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/student'),
        ),
        title: const Text('Notifications'),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, child) => TextButton(
              onPressed: controller.unreadCount == 0
                  ? null
                  : controller.markAllRead,
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, child) => _body(context, controller),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, NotificationController controller) {
    if (controller.state == ViewState.loading && controller.items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: ShimmerList());
    }
    if (controller.state == ViewState.error && controller.items.isEmpty) {
      return Center(
        child: ErrorView(
          message: controller.errorMessage ?? 'Could not load notifications.',
          onRetry: controller.load,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: controller.items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                EmptyState(message: 'No notifications yet.'),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: controller.items.length,
              itemBuilder: (context, index) {
                final item = controller.items[index];
                return Card(
                  color: item.read ? null : const Color(0xFFE3ECE9),
                  child: ListTile(
                    onTap: () => context.push(
                      '/student/complaints/${Uri.encodeComponent(item.complaintId)}',
                    ),
                    leading: CircleAvatar(
                      backgroundColor: item.read
                          ? const Color(0xFFEFEBE1)
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: item.read
                          ? AppColors.secondaryText
                          : Theme.of(context).colorScheme.onPrimary,
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                    title: Text(
                      item.message,
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(timeAgo(item.createdAt)),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}
