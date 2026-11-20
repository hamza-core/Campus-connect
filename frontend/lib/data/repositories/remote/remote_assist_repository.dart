import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/models/issue_suggestion.dart';
import '../assist_repository.dart';

final class RemoteAssistRepository implements AssistRepository {
  const RemoteAssistRepository(this._api);
  final ApiClient _api;

  @override
  Future<UploadedPhoto> uploadPhoto(Uint8List bytes) async {
    final response = await _api.upload('uploads', bytes, 'photo.jpg');
    final data = response['data']! as Map<String, Object?>;
    return UploadedPhoto(
      id: data['id']! as String,
      url: data['url']! as String,
    );
  }

  @override
  Future<Uint8List> downloadPhoto(String url) async =>
      Uint8List.fromList(await _api.download(url));

  @override
  Future<IssueSuggestion> analyze(String imageId, String? description) async {
    final response = await _api.request(
      'POST',
      'complaints/analyze',
      body: {
        'imageId': imageId,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return IssueSuggestion.fromJson(response['data']! as Map<String, Object?>);
  }

  @override
  Future<List<String>> frequentIssues(ComplaintCategory category) async {
    try {
      final response = await _api.request(
        'GET',
        'meta/frequent-issues',
        query: {'category': category.apiValue},
      );
      return [
        for (final item
            in (response['data'] as List).cast<Map<String, Object?>>())
          item['label']! as String,
      ];
    } on AppException {
      return const [];
    }
  }
}
