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
      SizedBox(
        width: 240,
        child: DropdownButton<ComplaintCategory>(
          isExpanded: true,
          value: controller.filter.category,
          hint: const Text('All categories'),
          items: [
            const DropdownMenuItem(child: Text('All categories')),
            for (final category in ComplaintCategory.values)
              DropdownMenuItem(
                value: category,
                child: Text(category.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => controller.setFilter(
            controller.filter.copyWith(category: () => value),
          ),
        ),
      ),
      SizedBox(
        width: 270,
        child: DropdownButton<String>(
          isExpanded: true,
          value: controller.filter.departmentId,
          hint: const Text('All departments'),
          items: [
            const DropdownMenuItem(child: Text('All departments')),
            for (final (id, name) in departments)
              DropdownMenuItem(
                value: id,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => controller.setFilter(
            controller.filter.copyWith(departmentId: () => value),
          ),
        ),
      ),
    ],
  );
}
