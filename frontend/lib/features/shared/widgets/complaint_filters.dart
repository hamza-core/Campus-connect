import 'package:flutter/material.dart';

import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/priority.dart';
import '../controllers/complaint_list_controller.dart';
import 'complaint_tile.dart';

final class ComplaintFilters extends StatelessWidget {
  const ComplaintFilters({
    super.key,
    required this.controller,
    required this.departments,
    this.showDepartment = true,
    this.showCategory = true,
    this.iconOnly = false,
  });
  final ComplaintListController controller;
  final List<(String, String)> departments;
  final bool showDepartment;

  /// Only the super admin spans categories; a department admin's list is already one department.
  final bool showCategory;

  /// Narrow screens: just the filter icon (placed beside the search box).
  final bool iconOnly;

  int get _activeCount =>
      (showCategory && controller.filter.category != null ? 1 : 0) +
      (showDepartment && controller.filter.departmentId != null ? 1 : 0) +
      (controller.filter.priority != null ? 1 : 0) +
      (controller.filter.year != null ? 1 : 0) +
      (controller.filter.overdueOnly ? 1 : 0);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (MediaQuery.sizeOf(context).width >= 600) {
        return _fields(compact: false);
      }
      final theme = Theme.of(context);
      if (iconOnly) {
        return Badge(
          isLabelVisible: _activeCount > 0,
          label: Text('$_activeCount'),
          child: IconButton.outlined(
            tooltip: 'Filters',
            icon: const Icon(Icons.tune_rounded),
            style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
              backgroundColor: _activeCount > 0
                  ? theme.colorScheme.primary.withValues(alpha: .1)
                  : null,
            ),
            onPressed: () => _openSheet(context),
          ),
        );
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: Badge(
          isLabelVisible: _activeCount > 0,
          label: Text('$_activeCount'),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Filters'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              backgroundColor: _activeCount > 0
                  ? theme.colorScheme.primary.withValues(alpha: .1)
                  : null,
            ),
            onPressed: () => _openSheet(context),
          ),
        ),
      );
    },
  );

  void _openSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, child) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter complaints',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: _activeCount == 0
                        ? null
                        : () => controller.setFilter(
                            controller.filter.copyWith(
                              category: () => null,
                              departmentId: () => null,
                              priority: () => null,
                              year: () => null,
                              overdueOnly: false,
                            ),
                          ),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _fields(compact: true),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Show results'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _field<T>({
    required String label,
    required IconData icon,
    required T? value,
    required String allLabel,
    required Map<T, String> options,
    required ValueChanged<T?> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T?>(
            isExpanded: true,
            borderRadius: BorderRadius.circular(18),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            value: value,
            hint: Text(allLabel),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: value == null ? FontWeight.w500 : FontWeight.w700,
              color: const Color(0xFF0F2A27),
            ),
            items: [
              DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
              for (final entry in options.entries)
                DropdownMenuItem<T?>(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );

  Widget _fields({required bool compact}) {
    final category = _field<ComplaintCategory>(
      label: 'Category',
      icon: Icons.category_outlined,
      value: controller.filter.category,
      allLabel: 'All categories',
      options: {for (final c in ComplaintCategory.values) c: c.label},
      onChanged: (value) => controller.setFilter(
        controller.filter.copyWith(category: () => value),
      ),
    );
    final department = _field<String>(
      label: 'Department',
      icon: Icons.apartment_rounded,
      value: controller.filter.departmentId,
      allLabel: 'All departments',
      options: {for (final (id, name) in departments) id: name},
      onChanged: (value) => controller.setFilter(
        controller.filter.copyWith(departmentId: () => value),
      ),
    );
    final priority = _field<Priority>(
      label: 'Priority',
      icon: Icons.flag_outlined,
      value: controller.filter.priority,
      allLabel: 'Any priority',
      options: {for (final p in Priority.values) p: p.label},
      onChanged: (value) => controller.setFilter(
        controller.filter.copyWith(priority: () => value),
      ),
    );
    final thisYear = DateTime.now().year;
    final year = _field<int>(
      label: 'Year',
      icon: Icons.calendar_month_outlined,
      value: controller.filter.year,
      allLabel: 'All years',
      options: {for (var y = thisYear; y > thisYear - 4; y--) y: '$y'},
      onChanged: (value) =>
          controller.setFilter(controller.filter.copyWith(year: () => value)),
    );
    final overdue = SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: const Text(
        'Overdue only',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      value: controller.filter.overdueOnly,
      onChanged: (value) =>
          controller.setFilter(controller.filter.copyWith(overdueOnly: value)),
    );
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCategory) ...[category, const SizedBox(height: 16)],
          if (showDepartment) ...[department, const SizedBox(height: 16)],
          priority,
          const SizedBox(height: 16),
          year,
          const SizedBox(height: 8),
          overdue,
        ],
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        if (showCategory) SizedBox(width: 260, child: category),
        if (showDepartment) SizedBox(width: 300, child: department),
        SizedBox(width: 220, child: priority),
        SizedBox(width: 160, child: year),
        SizedBox(width: 200, child: overdue),
      ],
    );
  }
}
