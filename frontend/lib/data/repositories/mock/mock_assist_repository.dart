import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/models/issue_suggestion.dart';
import '../assist_repository.dart';

/// Offline demo: no AI, no server photos.
final class MockAssistRepository implements AssistRepository {
  const MockAssistRepository();

  @override
  Future<UploadedPhoto> uploadPhoto(Uint8List bytes) async =>
      const UploadedPhoto(id: 'mock', url: '/api/v1/uploads/mock');

  @override
  Future<IssueSuggestion> analyze(String imageId, String? description) =>
      throw const ServerException('Photo analysis is not available offline.');

  @override
  Future<List<String>> frequentIssues(ComplaintCategory category) async =>
      const [];
}
