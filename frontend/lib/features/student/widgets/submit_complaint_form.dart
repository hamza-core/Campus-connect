import 'package:flutter/material.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/clay_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../domain/enums/complaint_category.dart';
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
  });
  final ComplaintCategory category;
  final SubmitComplaintController controller;
  final GlobalKey<FormState> form;
  final TextEditingController title;
  final TextEditingController description;

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(category.label, style: Theme.of(context).textTheme.headlineMedium),
        Text('This will be sent to ${_department(category)}.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: title,
          maxLength: 120,
          enabled: controller.state != ViewState.loading,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (value) => Validators.length(value, 'Title', 5, 120),
        ),
        TextFormField(
          controller: description,
          minLines: 4,
          maxLines: 8,
          maxLength: 3000,
          enabled: controller.state != ViewState.loading,
          decoration: const InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
          ),
          validator: (value) =>
              Validators.length(value, 'Description', 20, 3000),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text('Add photos (${controller.photos.length}/3)'),
          onPressed:
              controller.photos.length >= 3 ||
                  controller.picking ||
                  controller.state == ViewState.loading
              ? null
              : controller.pickPhotos,
        ),
        const Text(
          'Photos are saved on this device only. Staff cannot see them.',
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
