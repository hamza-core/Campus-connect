import 'package:flutter/material.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/clay_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/priority.dart';
import '../../shared/widgets/complaint_tile.dart';
import '../controllers/submit_complaint_controller.dart';

final class SubmitComplaintForm extends StatelessWidget {
  const SubmitComplaintForm({
    super.key,
    required this.category,
    required this.controller,
    required this.form,
    required this.title,
    required this.description,
    required this.location,
    required this.onUseCategory,
  });
  final ComplaintCategory category;
  final SubmitComplaintController controller;
  final GlobalKey<FormState> form;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController location;
  final ValueChanged<ComplaintCategory> onUseCategory;

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color.withValues(alpha: .16),
                border: Border.all(
                  color: category.color.withValues(alpha: .45),
                  width: 1.5,
                ),
              ),
              child: Icon(category.icon, color: category.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.label,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'This will be sent to ${_department(category)}.',
          style: const TextStyle(color: Color(0xFF5F6B68)),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('What kind of problem? (optional)'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final issue in controller.issueOptions(category))
                FilterChip(
                  label: Text(issue),
                  selected: controller.subIssue == issue,
                  onSelected: controller.state == ViewState.loading
                      ? null
                      : (_) => controller.chooseSubIssue(issue),
                  labelStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    color: controller.subIssue == issue
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
            ],
          ),
        ),
        _SuggestionCard(
          controller: controller,
          category: category,
          onUseCategory: onUseCategory,
        ),
        const _FieldLabel('Title'),
        TextFormField(
          controller: title,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          enabled: controller.state != ViewState.loading,
          decoration: const InputDecoration(
            hintText: 'Short summary of the problem',
            prefixIcon: Icon(Icons.title_rounded),
          ),
          validator: (value) => Validators.length(value, 'Title', 5, 120),
        ),
        const SizedBox(height: 8),
        const _FieldLabel('Description'),
        TextFormField(
          controller: description,
          minLines: 4,
          maxLines: 8,
          maxLength: 3000,
          textCapitalization: TextCapitalization.sentences,
          enabled: controller.state != ViewState.loading,
          decoration: const InputDecoration(
            hintText: 'What happened, where and when?',
            alignLabelWithHint: true,
          ),
          validator: (value) =>
              Validators.length(value, 'Description', 20, 3000),
        ),
        const SizedBox(height: 8),
        const _FieldLabel('Location (optional)'),
        TextFormField(
          controller: location,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          enabled: controller.state != ViewState.loading,
          decoration: const InputDecoration(
            hintText: 'e.g. Lab 3, Block B',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 8),
        const _FieldLabel('Priority'),
        SegmentedButton<Priority>(
          showSelectedIcon: false,
          segments: [
            for (final level in Priority.values)
              ButtonSegment(value: level, label: Text(level.label)),
          ],
          selected: {controller.priority},
          onSelectionChanged: controller.state == ViewState.loading
              ? null
              : (value) => controller.choosePriority(value.single),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text(
            'Hide my name from department staff',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('The campus super admin can still see it.'),
          value: controller.anonymous,
          onChanged: controller.state == ViewState.loading
              ? null
              : controller.setAnonymous,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text('Add photos (${controller.photos.length}/3)'),
          onPressed:
              controller.photos.length >= 3 ||
                  controller.picking ||
                  controller.state == ViewState.loading
              ? null
              : () => controller.pickPhotos(description: description.text),
        ),
        const Text(
          'Add a photo and our AI suggests the issue. Photos are uploaded and attached to your complaint.',
        ),
        if (controller.photoMessage case final message?)
          ErrorView(message: message),
        if (controller.photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < controller.photos.length; index++)
                  Stack(
                    children: [
                      Image.memory(
                        controller.photos[index],
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        cacheWidth: 184,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove photo ${index + 1}',
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => controller.removePhoto(index),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (controller.errorMessage case final error?)
          ErrorView(message: error),
        const SizedBox(height: 16),
        ClayButton(
          label: 'Submit complaint',
          busy: controller.state == ViewState.loading,
          onPressed: controller.picking
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  FocusScope.of(context).unfocus();
                  controller.submit(
                    category,
                    title.text.trim(),
                    description.text.trim(),
                    location: location.text.trim(),
                  );
                },
        ),
      ],
    ),
  );

  String _department(ComplaintCategory category) => switch (category) {
    ComplaintCategory.cafeteria => 'Cafeteria Administration',
    ComplaintCategory.library => 'Library Administration',
    ComplaintCategory.labsAndIt => 'Laboratory / IT Administration',
    ComplaintCategory.academic => 'Teaching Manager / Academic Coordination',
  };
}

final class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

final class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.controller,
    required this.category,
    required this.onUseCategory,
  });
  final SubmitComplaintController controller;
  final ComplaintCategory category;
  final ValueChanged<ComplaintCategory> onUseCategory;

  @override
  Widget build(BuildContext context) {
    final value = controller.suggestion;
    if (controller.suggesting) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('AI is looking at your photo…'),
          ],
        ),
      );
    }
    if (value == null) {
      final message = controller.suggestionMessage;
      return message == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(message),
            );
    }
    final suggested = ComplaintCategory.values.firstWhere(
      (c) => c.apiValue == value.category,
      orElse: () => category,
    );
    final differs = suggested != category;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
        border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI suggests: ${value.issue}${value.isNewIssue ? ' (new)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (value.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(value.summary),
          ],
          if (differs) ...[
            const SizedBox(height: 6),
            Text('This looks like ${suggested.label}, not ${category.label}.'),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: controller.applySuggestion,
                child: Text('Use "${value.issue}"'),
              ),
              if (differs)
                OutlinedButton(
                  onPressed: () => onUseCategory(suggested),
                  child: Text('Switch to ${suggested.label}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
