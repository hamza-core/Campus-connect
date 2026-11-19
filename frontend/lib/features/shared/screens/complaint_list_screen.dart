import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../di/app_scope.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_summary.dart';
import '../controllers/complaint_list_controller.dart';
import '../widgets/complaint_tile.dart';

final class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({
    super.key,
    required this.basePath,
    required this.title,
    this.student = false,
    this.department = false,
    this.superAdmin = false,
  });
  final String basePath;
  final String title;
  final bool student;
  final bool department;
  final bool superAdmin;

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

final class _ComplaintListScreenState extends State<ComplaintListScreen> {
  ComplaintListController? _controller;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _history = false;
  List<(String, String)> _departments = const [];
  Map<ComplaintStatus?, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 320 &&
          _controller?.pageError == null) {
        _controller?.loadMore();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final dependencies = AppScope.of(context);
    _controller = ComplaintListController(
      dependencies.complaints,
      department: widget.department,
    );
    _controller!.refresh();
    if (widget.superAdmin) {
      dependencies.dashboard
          .byDepartment()
          .then((values) {
            if (!mounted) return;
            setState(
              () => _departments = values
                  .map((value) => (value.department.id, value.department.name))
                  .toList(),
            );
          })
          .catchError((Object _) {});
    }
    if (widget.student) _loadCounts();
  }

  Future<void> _loadCounts() async {
    final repository = AppScope.of(context).complaints;
    final filter = _controller!.filter;
    try {
      final statuses = [null, ...ComplaintStatus.values];
      final pages = await Future.wait([
        for (final status in statuses)
          repository.list(
            pageSize: 1,
            filter: filter.copyWith(status: () => status),
          ),
      ]);
      if (mounted) {
        setState(
          () => _counts = {
            for (var i = 0; i < statuses.length; i++)
              statuses[i]: pages[i].total,
          },
        );
      }
    } on Exception {
      // List errors are shown independently of optional filter counts.
    }
  }

  Future<void> _refresh() async {
    await _controller!.refresh();
    if (mounted && widget.student) await _loadCounts();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _controller?.dispose();
    super.dispose();
  }

  List<ComplaintStatus> get _statuses => !widget.department
      ? ComplaintStatus.values
      : _history
      ? const [ComplaintStatus.resolved, ComplaintStatus.rejected]
      : const [ComplaintStatus.pending, ComplaintStatus.inProgress];

  Future<void> _open(ComplaintSummary item) async {
    await context.push('${widget.basePath}/${Uri.encodeComponent(item.id)}');
    if (mounted && !widget.student) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.headlineMedium),
              if (widget.department) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Current')),
                    ButtonSegment(value: true, label: Text('History')),
                  ],
                  selected: {_history},
                  onSelectionChanged: (value) {
                    setState(() => _history = value.single);
                    controller.setDepartmentHistory(_history);
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: controller.search,
                decoration: const InputDecoration(
                  labelText: 'Search complaints',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              if (widget.superAdmin) const SizedBox(height: 8),
              if (widget.superAdmin) _adminFilters(controller),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: controller,
                builder: (context, child) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final status in [null, ..._statuses])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              '${status?.label ?? 'All'}${_counts[status] == null ? '' : ' ${_counts[status]}'}',
                            ),
                            selected: controller.filter.status == status,
                            onSelected: (_) => controller.setFilter(
                              controller.filter.copyWith(status: () => status),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
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
                    onRetry: _refresh,
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final table = !widget.student && constraints.maxWidth >= 690;
                  final itemCount = controller.items.length;
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: itemCount == 0
                          ? 1
                          : itemCount + (table ? 2 : 1),
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
                            onTap: () => _open(item),
                          );
                        }
                        final group = _dateGroup(item.createdAt);
                        final showGroup =
                            widget.student &&
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
                            ComplaintTile(item: item, onTap: () => _open(item)),
                          ],
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
    return widget.student ? ResponsiveCenter(child: content) : content;
  }

  Widget _adminFilters(ComplaintListController controller) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (MediaQuery.sizeOf(context).width < 600) {
        return OutlinedButton.icon(
          icon: const Icon(Icons.filter_list),
          label: const Text('Filters'),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, child) => _filterControls(controller),
                ),
              ),
            ),
          ),
        );
      }
      return _filterControls(controller);
    },
  );

  Widget _filterControls(ComplaintListController controller) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      DropdownButton<ComplaintCategory>(
        value: controller.filter.category,
        hint: const Text('All categories'),
        items: [
          const DropdownMenuItem(child: Text('All categories')),
          for (final category in ComplaintCategory.values)
            DropdownMenuItem(value: category, child: Text(category.label)),
        ],
        onChanged: (value) => controller.setFilter(
          controller.filter.copyWith(category: () => value),
        ),
      ),
      DropdownButton<String>(
        value: controller.filter.departmentId,
        hint: const Text('All departments'),
        items: [
          const DropdownMenuItem(child: Text('All departments')),
          for (final (id, name) in _departments)
            DropdownMenuItem(value: id, child: Text(name)),
        ],
        onChanged: (value) => controller.setFilter(
          controller.filter.copyWith(departmentId: () => value),
        ),
      ),
    ],
  );

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
