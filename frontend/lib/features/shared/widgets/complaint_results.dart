import 'package:flutter/material.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/entrance_motion.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/models/complaint_summary.dart';
import '../controllers/complaint_list_controller.dart';
import 'complaint_tile.dart';

final class ComplaintResults extends StatelessWidget {
  const ComplaintResults({
    super.key,
    required this.controller,
    required this.scroll,
    required this.student,
    required this.onRefresh,
    required this.onOpen,
  });
  final ComplaintListController controller;
  final ScrollController scroll;
  final bool student;
  final Future<void> Function() onRefresh;
  final ValueChanged<ComplaintSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (controller.state == ViewState.loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerList(),
            );
          }
          if (controller.state == ViewState.error) {
            return Center(
              child: ErrorView(
                message: controller.errorMessage!,
                onRetry: onRefresh,
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, _) {
              final table =
                  !student &&
                  MediaQuery.sizeOf(context).width >=
                      Responsive.adminWideNavigation;
              final itemCount = controller.items.length;
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.builder(
                  controller: scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: itemCount == 0 ? 1 : itemCount + (table ? 2 : 1),
                  itemBuilder: (context, index) {
                    if (itemCount == 0) {
                      return const EmptyState(
                        message: 'No complaints match your filters.',
                      );
                    }
                    if (table && index == 0) {
                      return const _ComplaintTableHeader();
                    }
                    final itemIndex = table ? index - 1 : index;
                    if (itemIndex == itemCount) return _tail(controller);
                    final item = controller.items[itemIndex];
                    if (table) {
                      return _ComplaintTableRow(
                        item: item,
                        onTap: () => onOpen(item),
                      );
                    }
                    final group = _dateGroup(item.createdAt);
                    final showGroup =
                        student &&
                        (itemIndex == 0 ||
                            _dateGroup(
                                  controller.items[itemIndex - 1].createdAt,
                                ) !=
                                group);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showGroup)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 0, 4),
                            child: Text(
                              group,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        if (student)
                          EntranceMotion(
                            index: itemIndex,
                            child: ComplaintTile(
                              item: item,
                              onTap: () => onOpen(item),
                            ),
                          )
                        else
                          ComplaintTile(item: item, onTap: () => onOpen(item)),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _tail(ComplaintListController controller) {
    if (controller.loadingMore) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.pageError case final error?) {
      return ErrorView(message: error, onRetry: controller.loadMore);
    }
    return controller.hasMore
        ? TextButton(
            onPressed: controller.loadMore,
            child: const Text('Load more'),
          )
        : const SizedBox.shrink();
  }

  String _dateGroup(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    return local.isAfter(
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
        )
        ? 'This week'
        : 'Earlier';
  }
}

final class _ComplaintTableHeader extends StatelessWidget {
  const _ComplaintTableHeader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(flex: 3, child: Text('Complaint')),
        Expanded(flex: 2, child: Text('Department')),
        Expanded(child: Text('Status')),
        Expanded(child: Text('Submitted')),
      ],
    ),
  );
}

final class _ComplaintTableRow extends StatelessWidget {
  const _ComplaintTableRow({required this.item, required this.onTap});
  final ComplaintSummary item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text('${item.title}\n${item.ticket}')),
            Expanded(flex: 2, child: Text(item.department.name)),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(status: item.status),
              ),
            ),
            Expanded(child: Text(DateFormatter.date(item.createdAt))),
          ],
        ),
      ),
    ),
  );
}
