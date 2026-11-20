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

  static (String, IconData, AppButtonTone) _look(ComplaintStatus status) =>
      switch (status) {
        ComplaintStatus.inProgress => (
          'Start work',
          Icons.play_arrow_rounded,
          AppButtonTone.info,
        ),
        ComplaintStatus.resolved => (
          'Resolve',
          Icons.check_circle_outline_rounded,
          AppButtonTone.success,
        ),
        ComplaintStatus.rejected => (
          'Reject',
          Icons.block_rounded,
          AppButtonTone.destructive,
        ),
        ComplaintStatus.pending => (
          'Pending',
          Icons.schedule_rounded,
          AppButtonTone.neutral,
        ),
      };

  Future<void> _change(BuildContext context, ComplaintStatus status) async {
    final final_ =
        status == ComplaintStatus.resolved ||
        status == ComplaintStatus.rejected;
    if (final_ && remark.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Write a reason in the remark box first.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    if (final_) {
      final (label, _, tone) = _look(status);
      final reject = status == ComplaintStatus.rejected;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: Icon(
            reject ? Icons.block_rounded : Icons.check_circle_outline_rounded,
            color: reject ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
            size: 32,
          ),
          title: Text('$label this complaint?'),
          content: Text(
            reject
                ? 'The student is notified and sees your reason. A rejected complaint cannot be reopened.'
                : 'The student is notified and sees your reply. A resolved complaint cannot be reopened.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: label,
              tone: tone,
              onPressed: () => Navigator.pop(dialog, true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await controller.update(status, remark.text);
  }

  @override
  Widget build(BuildContext context) {
    final transitions = controller.complaint!.allowedTransitions;
    return ComplaintSection(
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
          AppButton(
            label: 'Post remark',
            icon: Icons.chat_bubble_outline_rounded,
            tone: AppButtonTone.neutral,
            busy: controller.saving,
            onPressed: () async {
              final posted = await controller.addRemark(remark.text);
              if (posted && context.mounted) remark.clear();
            },
          ),
          if (transitions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Change status',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in transitions)
                  AppButton(
                    label: _look(status).$1,
                    icon: _look(status).$2,
                    tone: _look(status).$3,
                    busy: controller.saving,
                    onPressed: () => _change(context, status),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
