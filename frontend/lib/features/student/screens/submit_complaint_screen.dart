import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/storage/complaint_photo_store.dart';
import '../../../core/widgets/clay_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../di/app_scope.dart';
import '../../../domain/enums/complaint_category.dart';
import '../controllers/submit_complaint_controller.dart';
import '../widgets/complaint_category_card.dart';
import '../widgets/submit_complaint_form.dart';

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
  final _location = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= SubmitComplaintController(
      AppScope.of(context).complaints,
      ComplaintPhotoStore.instance,
      widget.ownerId,
      AppScope.of(context).assist,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
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
                Semantics(
                  label: 'Step ${category == null ? 1 : 2} of 2',
                  child: Row(
                    children: [
                      Text(
                        'STEP ${category == null ? 1 : 2} OF 2',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              letterSpacing: 1,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5F6B68),
                            ),
                      ),
                      const SizedBox(width: 12),
                      for (final filled in [true, category != null]) ...[
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: filled
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFFDAD5C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        if (filled == true) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (category == null) ...[
                  Text(
                    "What's the issue about?",
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Pick a category and we'll send it to the right team.",
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in ComplaintCategory.values)
                          SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: ComplaintCategoryCard(
                              item: item,
                              onTap: () {
                                _controller!.resetForCategory();
                                _controller!.loadIssues(item);
                                setState(() => _category = item);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  SubmitComplaintForm(
                    category: category,
                    controller: controller,
                    form: _form,
                    title: _title,
                    description: _description,
                    location: _location,
                    onUseCategory: (value) {
                      _controller!.resetForCategory();
                      _controller!.applySuggestion();
                      _controller!.loadIssues(value);
                      setState(() => _category = value);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
