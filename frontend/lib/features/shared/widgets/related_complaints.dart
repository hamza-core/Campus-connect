import 'package:flutter/material.dart';

import '../../../domain/models/complaint_summary.dart';
import 'complaint_section.dart';
import 'complaint_tile.dart';

/// Other complaints about the same kind of problem (same category and issue
/// label) that the viewer may see. Hidden when there are none.
final class RelatedComplaints extends StatelessWidget {
  const RelatedComplaints({
    super.key,
    required this.related,
    required this.onOpen,
  });
  final Future<List<ComplaintSummary>> related;
  final ValueChanged<ComplaintSummary> onOpen;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ComplaintSummary>>(
    future: related,
    builder: (context, snapshot) {
      final items = snapshot.data;
      if (items == null || items.isEmpty) return const SizedBox.shrink();
      return ComplaintSection(
        title: 'Related complaints (${items.length})',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Same category and kind of problem.'),
            ),
            for (final item in items)
              ComplaintTile(item: item, onTap: () => onOpen(item)),
          ],
        ),
      );
    },
  );
}
