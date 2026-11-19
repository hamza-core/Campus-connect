import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_summary.dart';
import '../controllers/complaint_list_controller.dart';
import '../widgets/complaint_filters.dart';
import '../widgets/complaint_results.dart';

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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!keyboardOpen)
                Text(
                  widget.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (_counts[null] != null)
                Text(
                  '${_counts[null]} complaints',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5F6B68),
                  ),
                ),
              if (!keyboardOpen && widget.department) ...[
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
                  hintText: 'Search complaints',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              if (!keyboardOpen && widget.superAdmin) const SizedBox(height: 8),
              if (!keyboardOpen && widget.superAdmin)
                ComplaintFilters(
                  controller: controller,
                  departments: _departments,
                ),
              const SizedBox(height: 8),
              if (!keyboardOpen)
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
                              labelStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                color: controller.filter.status == status
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                              onSelected: (_) => controller.setFilter(
                                controller.filter.copyWith(
                                  status: () => status,
                                ),
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
        ComplaintResults(
          controller: controller,
          scroll: _scroll,
          student: widget.student,
          onRefresh: _refresh,
          onOpen: _open,
        ),
      ],
    );
    return widget.student ? ResponsiveCenter(child: content) : content;
  }
}
