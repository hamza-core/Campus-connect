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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) {
      if (MediaQuery.sizeOf(context).width < 600) {
        final active =
            (controller.filter.category != null ? 1 : 0) +
            (controller.filter.departmentId != null ? 1 : 0);
        return OutlinedButton.icon(
          icon: const Icon(Icons.filter_list),
          label: Text(active == 0 ? 'Filters' : 'Filters ($active)'),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, child) =>
                      _filterControls(controller, compact: true),
                ),
              ),
            ),
          ),
        );
      }
      return _filterControls(controller, compact: false);
    },
  );

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required String allLabel,
    required Map<T, String> options,
    required ValueChanged<T?> onChanged,
  }) => InputDecorator(
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T?>(
        isExpanded: true,
        borderRadius: BorderRadius.circular(18),
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        value: value,
        hint: Text(hint),
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
  );

  Widget _filterControls(
    ComplaintListController controller, {
    required bool compact,
  }) {
    final category = _dropdown<ComplaintCategory>(
      value: controller.filter.category,
      hint: 'All categories',
      allLabel: 'All categories',
      options: {for (final c in ComplaintCategory.values) c: c.label},
      onChanged: (value) => controller.setFilter(
        controller.filter.copyWith(category: () => value),
      ),
    );
    final department = _dropdown<String>(
      value: controller.filter.departmentId,
      hint: 'All departments',
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
        children: [category, const SizedBox(height: 12), department],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        SizedBox(width: 260, child: category),
        SizedBox(width: 300, child: department),
      ],
    );
  }
}
