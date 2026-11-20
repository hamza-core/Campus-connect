import 'package:flutter/material.dart';

import '../../../domain/models/complaint_summary.dart';
import 'complaint_tile.dart';

/// Other complaints about the same kind of problem (same category and issue
/// label) that the viewer may see. Collapsed by default; hidden when none.
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCFC9B8), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(
                'Related complaints (${items.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Same category and kind of problem'),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final item in items)
                  ComplaintTile(item: item, onTap: () => onOpen(item)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
