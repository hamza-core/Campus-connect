import 'package:flutter/material.dart';

import '../../../domain/models/complaint_feedback.dart';
import '../controllers/complaint_detail_controller.dart';

/// Read-only stars for an existing rating.
final class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 24});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rated $rating out of 5',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: const Color(0xFFE0A100),
          ),
      ],
    ),
  );
}

/// Shows the student's rating, or lets them rate a resolved complaint once.
final class FeedbackSection extends StatefulWidget {
  const FeedbackSection({
    super.key,
    required this.controller,
    required this.feedback,
    required this.canRate,
  });
  final ComplaintDetailController controller;
  final ComplaintFeedback? feedback;
  final bool canRate;

  @override
  State<FeedbackSection> createState() => _FeedbackSectionState();
}

final class _FeedbackSectionState extends State<FeedbackSection> {
  int _rating = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    if (feedback != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StarRow(rating: feedback.rating),
          if (feedback.comment case final text? when text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text),
          ],
        ],
      );
    }
    if (!widget.canRate) return const Text('No rating yet.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('How was the response? Tap a star to rate it.'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i star${i == 1 ? '' : 's'}',
                onPressed: widget.controller.saving
                    ? null
                    : () => setState(() => _rating = i),
                icon: Icon(
                  i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 34,
                  color: const Color(0xFFE0A100),
                ),
              ),
          ],
        ),
        TextField(
          controller: _comment,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          enabled: !widget.controller.saving,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _rating == 0 || widget.controller.saving
              ? null
              : () => widget.controller.rate(_rating, _comment.text),
          child: widget.controller.saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send rating'),
        ),
      ],
    );
  }
}
