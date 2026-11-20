import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/auto_refresh.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_summary.dart';
import '../controllers/complaint_list_controller.dart';
import '../../../domain/models/complaint_filter.dart';
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
    this.initialStatus,
    this.initialOverdue = false,
  });
  final String basePath;
  final String title;
  final bool student;
  final bool department;
  final bool superAdmin;

  /// Opened from a dashboard card: start with this status / overdue filter.
  final ComplaintStatus? initialStatus;
  final bool initialOverdue;

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

final class _ComplaintListScreenState extends State<ComplaintListScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefresh;
  Listenable? _live;
  ComplaintListController? _controller;
  final _scroll = ScrollController();
  final _search = TextEditingController();
  bool _history = false;
  List<(String, String)> _departments = const [];
  Map<ComplaintStatus?, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoRefresh = Timer.periodic(
      autoRefreshInterval,
      (_) => _checkForUpdates(),
    );
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
      cache: dependencies.cache,
      scope: widget.basePath,
    );
    final status = widget.initialStatus;
    if (status != null || widget.initialOverdue) {
      if (widget.department &&
          (status == ComplaintStatus.resolved ||
              status == ComplaintStatus.rejected)) {
        _history = true;
        _controller!.setDepartmentHistory(true);
      }
      _controller!.setFilter(
        _controller!.filter.copyWith(
          status: () => status,
          overdueOnly: widget.initialOverdue,
        ),
      );
    } else {
      _controller!.start();
    }
    // A live notification means a complaint was added or just changed.
    _live = dependencies.notifications..addListener(_checkForUpdates);
    _countsKey = _controller!.filter;
    _controller!.addListener(_onControllerChange);
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
    if (widget.student) {
      final cached = dependencies.cache.read<Map<ComplaintStatus?, int>>(
        _countsCacheKey,
      );
      if (cached != null) _counts = cached;
      _loadCounts();
    }
  }

  String get _countsCacheKey {
    final f = _controller!.filter;
    return 'list-counts:${widget.basePath}|${f.search}|${f.category}|${f.departmentId}|${f.overdueOnly}|${f.year}';
  }

  ComplaintFilter? _countsKey;

  /// The status-chip counts follow the search/filter, so reload them when it changes.
  void _onControllerChange() {
    final filter = _controller!.filter;
    final previous = _countsKey;
    if (previous == null) return;
    if (filter.search != previous.search ||
        filter.category != previous.category ||
        filter.departmentId != previous.departmentId ||
        filter.overdueOnly != previous.overdueOnly ||
        filter.year != previous.year) {
      _countsKey = filter;
      if (widget.student) _loadCounts();
    }
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
        final counts = {
          for (var i = 0; i < statuses.length; i++) statuses[i]: pages[i].total,
        };
        AppScope.of(context).cache.write(_countsCacheKey, counts);
        setState(() => _counts = counts);
      }
    } on Exception {
      // List errors are shown independently of optional filter counts.
    }
  }

  Future<void> _refresh() async {
    await _controller!.refresh();
    if (mounted && widget.student) await _loadCounts();
  }

  /// Quietly picks up new complaints and status changes. Skipped while the
  /// user is reading further down the list, so nothing jumps under their finger.
  bool _exporting = false;

  /// Exports the (filtered) list as a CSV file through the system share sheet.
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await AppScope.of(context).complaints
          .exportCsv(filter: _controller!.filter);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(csv)),
              mimeType: 'text/csv',
              name: 'complaints.csv',
            ),
          ],
          fileNameOverrides: const ['complaints.csv'],
          subject: 'CampusConnect complaints',
        ),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not export the complaints.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _checkForUpdates() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (_scroll.hasClients && _scroll.offset > 120) return;
    _controller?.silentRefresh();
    if (widget.student) _loadCounts();
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
    _controller?.removeListener(_onControllerChange);
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
    if (mounted) await _refresh();
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.department || widget.superAdmin)
                      IconButton.outlined(
                        tooltip: 'Export CSV',
                        onPressed: _exporting ? null : _export,
                        icon: _exporting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded),
                      ),
                  ],
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
              Builder(
                builder: (context) {
                  final narrow = MediaQuery.sizeOf(context).width < 600;
                  final staff = widget.superAdmin || widget.department;
                  final search = TextField(
                    controller: _search,
                    onChanged: controller.search,
                    decoration: const InputDecoration(
                      hintText: 'Search complaints',
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                  final filters = ComplaintFilters(
                    controller: controller,
                    departments: _departments,
                    showDepartment: widget.superAdmin,
                    showCategory: widget.superAdmin,
                    iconOnly: narrow,
                  );
                  if (keyboardOpen || !staff) return search;
                  if (narrow) {
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 8),
                        filters,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 8), filters],
                  );
                },
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
