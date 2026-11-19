import 'package:flutter/material.dart';

import '../../../core/widgets/app_button.dart';
import '../../../domain/enums/complaint_status.dart';
import '../controllers/complaint_detail_controller.dart';
import 'complaint_section.dart';

final class DepartmentComplaintActions extends StatelessWidget {
  const DepartmentComplaintActions({
    super.key,
    required this.controller,
    required this.remark,
  });
  final ComplaintDetailController controller;
  final TextEditingController remark;

  @override
  Widget build(BuildContext context) => ComplaintSection(
    title: 'Department actions',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: remark,
          maxLength: 2000,
          minLines: 2,
          maxLines: 4,
          enabled: !controller.saving,
          decoration: const InputDecoration(
            labelText: 'Department remark',
            helperText: 'A reason is required to resolve or reject.',
            helperMaxLines: 2,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: 'Post remark',
              busy: controller.saving,
              onPressed: () async {
                final posted = await controller.addRemark(remark.text);
                if (posted && context.mounted) remark.clear();
              },
            ),
            for (final status in controller.complaint!.allowedTransitions)
              AppButton(
                label: switch (status) {
                  ComplaintStatus.inProgress => 'Start work',
                  ComplaintStatus.resolved => 'Resolve',
                  ComplaintStatus.rejected => 'Reject',
                  ComplaintStatus.pending => 'Pending',
                },
                busy: controller.saving,
                onPressed: () => controller.update(status, remark.text),
              ),
          ],
        ),
      ],
    ),
  );
}
