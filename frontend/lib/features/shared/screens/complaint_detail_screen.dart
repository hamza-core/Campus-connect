import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/storage/complaint_photo_store.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../di/app_scope.dart';
import '../../../domain/enums/complaint_status.dart';
import '../controllers/complaint_detail_controller.dart';
import 'access_denied_screen.dart';

final class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.id,
    required this.backPath,
    this.photoOwnerId,
    this.canUpdate = false,
  });
  final String id;
  final String backPath;
  final String? photoOwnerId;
  final bool canUpdate;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

final class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  ComplaintDetailController? _controller;
  Future<List<Uint8List>>? _photos;
  final _remark = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ComplaintDetailController(
      AppScope.of(context).complaints,
      widget.id,
    )..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final theme = Theme.of(context);
    final isStudent = widget.photoOwnerId != null;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (controller.forbidden) return const AccessDeniedScreen();
        final complaint = controller.complaint;
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(widget.backPath),
            ),
            title: Text(complaint?.summary.ticket ?? 'Complaint detail'),
          ),
          body: ResponsiveCenter(
            maxWidth: isStudent ? 480 : 850,
            child: controller.state == ViewState.loading && complaint == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(),
                  )
                : complaint == null
                ? ErrorView(
                    message:
                        controller.errorMessage ?? 'Complaint unavailable.',
                    onRetry: controller.load,
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (isStudent)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              complaint.summary.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          complaint.summary.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: complaint.summary.status),
                          Text(complaint.summary.department.name),
                        ],
                      ),
                      if (!isStudent && complaint.authorName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('Submitted by ${complaint.authorName}'),
                        ),
                      _Section(
                        title: 'Description',
                        child: SelectableText(complaint.description),
                      ),
                      if (widget.photoOwnerId case final owner?)
                        FutureBuilder<List<Uint8List>>(
                          future: _photos ??= ComplaintPhotoStore.instance.read(
                            owner,
                            widget.id,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const ErrorView(
                                message: 'Saved photos could not be opened.',
                              );
                            }
                            final images = snapshot.data;
                            if (images == null || images.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return _Section(
                              title: 'Photos saved on this device',
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final image in images)
                                    InkWell(
                                      onTap: () => showDialog<void>(
                                        context: context,
                                        builder: (context) => Dialog(
                                          child: InteractiveViewer(
                                            child: Image.memory(image),
                                          ),
                                        ),
                                      ),
                                      child: Image.memory(
                                        image,
                                        height: 92,
                                        width: 92,
                                        fit: BoxFit.cover,
                                        cacheWidth: 184,
                                        semanticLabel: 'Attached photo',
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (complaint.timeline.any((entry) => entry.body != null))
                        _Section(
                          title: 'Department remarks',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in complaint.timeline)
                                if (entry.body case final body?)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(body),
                                  ),
                            ],
                          ),
                        ),
                      _Section(
                        title: 'Timeline',
                        child: Column(
                          children: [
                            for (final entry in complaint.timeline)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(
                                  entry.toStatus?.label ??
                                      (entry.type == 'REMARK'
                                          ? 'Remark added'
                                          : 'Submitted'),
                                ),
                                subtitle: Text(
                                  '${DateFormatter.date(entry.createdAt)}${entry.actorName == null ? '' : ' · ${entry.actorName}'}',
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (controller.actionError case final message?)
                        ErrorView(message: message),
                      if (widget.canUpdate &&
                          complaint.allowedTransitions.isNotEmpty)
                        _Section(
                          title: 'Update status',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _remark,
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
                                  for (final status
                                      in complaint.allowedTransitions)
                                    AppButton(
                                      label: switch (status) {
                                        ComplaintStatus.inProgress =>
                                          'Start work',
                                        ComplaintStatus.resolved => 'Resolve',
                                        ComplaintStatus.rejected => 'Reject',
                                        ComplaintStatus.pending => 'Pending',
                                      },
                                      busy: controller.saving,
                                      onPressed: () => controller.update(
                                        status,
                                        _remark.text,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    ),
  );
}
