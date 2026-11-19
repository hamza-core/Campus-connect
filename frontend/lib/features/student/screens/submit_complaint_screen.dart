import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/storage/complaint_photo_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/clay_button.dart';
import '../../../core/widgets/clay_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/illustration_image.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../shared/widgets/complaint_tile.dart';
import '../controllers/submit_complaint_controller.dart';

final class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key, required this.ownerId});
  final String ownerId;

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

final class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  SubmitComplaintController? _controller;
  ComplaintCategory? _category;
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= SubmitComplaintController(
      AppScope.of(context).complaints,
      ComplaintPhotoStore.instance,
      widget.ownerId,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _finish() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/student/complaints');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final category = _category;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an issue'),
        leading: BackButton(
          onPressed: () {
            if (controller.state == ViewState.loading) return;
            if (controller.submitted != null) {
              _finish();
            } else if (_category != null) {
              setState(() => _category = null);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/student');
            }
          },
        ),
      ),
      body: ResponsiveCenter(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            if (controller.submitted case final complaint?) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .7, end: 1),
                        duration: const Duration(milliseconds: 350),
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 62,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Complaint submitted',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(complaint.summary.ticket),
                      if (controller.photoMessage case final message?)
                        ErrorView(message: message),
                      const SizedBox(height: 16),
                      ClayButton(label: 'Done', onPressed: _finish),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                LinearProgressIndicator(
                  value: category == null ? .5 : 1,
                  semanticsLabel: 'Step ${category == null ? 1 : 2} of 2',
                ),
                const SizedBox(height: 16),
                if (category == null) ...[
                  Text(
                    "What's the issue about?",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Pick a category and we'll send it to the right team.",
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in ComplaintCategory.values)
                          SizedBox(
                            width: (constraints.maxWidth - 10) / 2,
                            child: _CategoryCard(
                              item: item,
                              onTap: () => setState(() => _category = item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  _formBody(category, controller),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _formBody(
    ComplaintCategory category,
    SubmitComplaintController controller,
  ) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(category.label, style: Theme.of(context).textTheme.headlineMedium),
        Text('This will be sent to ${_department(category)}.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: _title,
          maxLength: 120,
          enabled: controller.state != ViewState.loading,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (value) => Validators.length(value, 'Title', 5, 120),
        ),
        TextFormField(
          controller: _description,
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
                  if (!_form.currentState!.validate()) return;
                  FocusScope.of(context).unfocus();
                  controller.submit(
                    category,
                    _title.text.trim(),
                    _description.text.trim(),
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

final class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item, required this.onTap});
  final ComplaintCategory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (filename, color) = switch (item) {
      ComplaintCategory.cafeteria => ('cafeteria.jpg', AppColors.cafeteria),
      ComplaintCategory.library => ('library.jpg', AppColors.library),
      ComplaintCategory.labsAndIt => ('labs-it.jpg', AppColors.labsAndIt),
      ComplaintCategory.academic => (
        'teaching-academic.jpg',
        AppColors.academic,
      ),
    };
    return ClayCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IllustrationImage(filename: filename, size: 62),
                const SizedBox(height: 10),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
