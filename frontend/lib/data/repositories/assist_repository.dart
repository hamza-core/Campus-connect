import 'dart:typed_data';

import '../../domain/enums/complaint_category.dart';
import '../../domain/models/issue_suggestion.dart';

/// Photo upload, AI photo analysis and data-driven issue labels.
abstract interface class AssistRepository {
  Future<UploadedPhoto> uploadPhoto(Uint8List bytes);
  Future<IssueSuggestion> analyze(String imageId, String? description);

  /// Most frequently reported issue labels in [category] (empty on failure).
  Future<List<String>> frequentIssues(ComplaintCategory category);
}
