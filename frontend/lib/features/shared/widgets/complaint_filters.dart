import 'package:flutter/material.dart';

import '../../../domain/enums/complaint_category.dart';
import '../controllers/complaint_list_controller.dart';
import 'complaint_tile.dart';

final class ComplaintFilters extends StatelessWidget {
  const ComplaintFilters({
    super.key,
    required this.controller,
    required this.departments,
  });
  final ComplaintListController controller;
  final List<(String, String)> departments;

  int get _activeCount =>
      (controller.filter.category != null ? 1 : 0) +
      (controller.filter.departmentId != null ? 1 : 0);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (MediaQuery.sizeOf(context).width >= 600) {
        return _fields(compact: false);
      }
      final theme = Theme.of(context);
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
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [category, const SizedBox(height: 16), department],
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        SizedBox(width: 260, child: category),
        SizedBox(width: 300, child: department),
      ],
    );
  }
}
