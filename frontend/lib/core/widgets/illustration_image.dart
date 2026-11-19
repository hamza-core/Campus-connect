import 'package:flutter/widgets.dart';

import '../constants/asset_paths.dart';

final class IllustrationImage extends StatelessWidget {
  const IllustrationImage({
    super.key,
    required this.filename,
    required this.size,
    this.semanticLabel,
  });

  final String filename;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
    '${AssetPaths.illustrations}$filename',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}
