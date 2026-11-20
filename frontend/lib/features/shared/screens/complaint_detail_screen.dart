import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/storage/complaint_photo_store.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/shimmer_list.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../di/app_scope.dart';
import '../controllers/complaint_detail_controller.dart';
import '../../../domain/enums/complaint_status.dart';
import '../widgets/complaint_details_card.dart';
import '../widgets/complaint_photo_gallery.dart';
import '../widgets/rating_card.dart';
import '../widgets/complaint_section.dart';
import '../widgets/complaint_timeline.dart';
import '../widgets/department_complaint_actions.dart';
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
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .25),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  complaint.summary.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: theme.colorScheme.onPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    StatusBadge(
                                      status: complaint.summary.status,
                                    ),
                                    Text(
                                      complaint.summary.department.name,
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimary
                                            .withValues(alpha: .9),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          complaint.summary.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      const SizedBox(height: 12),
                      if (!isStudent)
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
                      ComplaintSection(
                        title: 'Details',
                        child: ComplaintDetailsCard(complaint: complaint),
                      ),
                      ComplaintSection(
                        title: 'Description',
                        child: SelectableText(complaint.description),
                      ),
                      if (complaint.imageUrls.isNotEmpty)
                        ComplaintPhotoGallery(
                          photos: _photos ??= Future.wait([
                            for (final url in complaint.imageUrls)
                              AppScope.of(context).assist.downloadPhoto(url),
                          ]),
                        )
                      else if (widget.photoOwnerId case final owner?)
                        ComplaintPhotoGallery(
                          photos: _photos ??= ComplaintPhotoStore.instance.read(
                            owner,
                            widget.id,
                          ),
                        ),
                      if (complaint.timeline.any((entry) => entry.body != null))
                        ComplaintSection(
                          title: 'Department remarks',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final entry in complaint.timeline)
                                if (entry.body case final body?)
                                  DepartmentReply(
                                    departmentName:
                                        complaint.summary.department.name,
                                    message: body,
                                  ),
                            ],
                          ),
                        ),
                      if (complaint.feedback != null ||
                          (isStudent &&
                              complaint.summary.status ==
                                  ComplaintStatus.resolved))
                        ComplaintSection(
                          title: isStudent ? 'Your rating' : 'Student rating',
                          child: FeedbackSection(
                            controller: controller,
                            feedback: complaint.feedback,
                            canRate: isStudent,
                          ),
                        ),
                      ComplaintSection(
                        title: 'Timeline',
                        child: ComplaintTimeline(
                          entries: complaint.timeline,
                          departmentName: complaint.summary.department.name,
                        ),
                      ),
                      if (controller.actionError case final message?)
                        ErrorView(message: message),
                      if (widget.canUpdate)
                        DepartmentComplaintActions(
                          controller: controller,
                          remark: _remark,
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
