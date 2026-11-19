import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/error_view.dart';
import 'complaint_section.dart';

final class ComplaintPhotoGallery extends StatelessWidget {
  const ComplaintPhotoGallery({super.key, required this.photos});
  final Future<List<Uint8List>> photos;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Uint8List>>(
    future: photos,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const ErrorView(message: 'Saved photos could not be opened.');
      }
      final images = snapshot.data;
      if (images == null || images.isEmpty) {
        return const SizedBox.shrink();
      }
      return ComplaintSection(
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
                    child: InteractiveViewer(child: Image.memory(image)),
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
  );
}
