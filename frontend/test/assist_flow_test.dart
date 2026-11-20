import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/storage/complaint_photo_store.dart';
import 'package:project/data/repositories/assist_repository.dart';
import 'package:project/data/repositories/mock/mock_auth_repository.dart';
import 'package:project/data/repositories/mock/mock_complaint_repository.dart';
import 'package:project/domain/enums/complaint_category.dart';
import 'package:project/domain/enums/priority.dart';
import 'package:project/domain/models/issue_suggestion.dart';
import 'package:project/features/student/controllers/submit_complaint_controller.dart';

final class _Assist implements AssistRepository {
  _Assist(this.frequent);
  final List<String> frequent;

  @override
  Future<UploadedPhoto> uploadPhoto(Uint8List bytes) async =>
      const UploadedPhoto(id: 'abcdef0123456789abcdef0123456789', url: '/api/v1/uploads/x');

  @override
  Future<IssueSuggestion> analyze(String imageId, String? description) async =>
      const IssueSuggestion(
        category: 'LAB_IT',
        issue: 'Projector not working',
        priority: 'HIGH',
        summary: 's',
        isNewIssue: true,
      );

  @override
  Future<List<String>> frequentIssues(ComplaintCategory category) async =>
      frequent;
}

SubmitComplaintController _controller(List<String> frequent) {
  final auth = MockAuthRepository();
  return SubmitComplaintController(
    MockComplaintRepository(auth),
    ComplaintPhotoStore.instance,
    'owner',
    _Assist(frequent),
  );
}

void main() {
  test(
    'issue chips come from the data, with the brief as a fallback',
    () async {
      final empty = _controller(const []);
      expect(
        empty.issueOptions(ComplaintCategory.labsAndIt),
        ComplaintCategory.labsAndIt.subIssues,
      );
      final learned = _controller(const ['Broken projector', 'Slow wifi']);
      await learned.loadIssues(ComplaintCategory.labsAndIt);
      expect(learned.issueOptions(ComplaintCategory.labsAndIt), [
        'Broken projector',
        'Slow wifi',
      ]);
    },
  );

  test('applying a suggestion sets the issue label and priority', () async {
    final controller = _controller(const ['Slow wifi']);
    controller.suggestion = const IssueSuggestion(
      category: 'LAB_IT',
      issue: 'Projector not working',
      priority: 'HIGH',
      summary: '',
      isNewIssue: true,
    );
    controller.applySuggestion();
    expect(controller.subIssue, 'Projector not working');
    expect(controller.priority, Priority.high);
    await controller.loadIssues(ComplaintCategory.labsAndIt);
    expect(
      controller.issueOptions(ComplaintCategory.labsAndIt).first,
      'Projector not working',
    );
  });
}
