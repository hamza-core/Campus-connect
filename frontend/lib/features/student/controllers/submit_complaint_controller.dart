import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/complaint_photo_store.dart';
import '../../../data/repositories/assist_repository.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/priority.dart';
import '../../../domain/models/complaint.dart';
import '../../../domain/models/issue_suggestion.dart';

final class SubmitComplaintController extends BaseController {
  SubmitComplaintController(
    this._repository,
    this._photoStore,
    this._ownerId,
    this._assist,
  );
  final ComplaintRepository _repository;
  final AssistRepository _assist;
  final ComplaintPhotoStore _photoStore;
  final String _ownerId;
  final _picker = ImagePicker();
  final List<Uint8List> _photos = [];
  final List<UploadedPhoto> _uploaded = [];
  List<String> _frequent = const [];
  IssueSuggestion? suggestion;
  bool suggesting = false;
  String? suggestionMessage;
  List<Uint8List> get photos => List.unmodifiable(_photos);
  Complaint? submitted;
  String? subIssue;
  Priority priority = Priority.medium;
  bool anonymous = false;
  String? photoMessage;
  bool picking = false;

  /// Issue chips: the most frequently reported labels, or the brief's examples
  /// until the database has any.
  List<String> issueOptions(ComplaintCategory category) {
    final options = [..._frequent.isEmpty ? category.subIssues : _frequent];
    final picked = subIssue;
    if (picked != null && !options.contains(picked)) options.insert(0, picked);
    return options;
  }

  Future<void> loadIssues(ComplaintCategory category) async {
    _frequent = await _assist.frequentIssues(category);
    safeNotify();
  }

  /// Fill the issue label and priority from the AI suggestion.
  void applySuggestion() {
    final value = suggestion;
    if (value == null) return;
    subIssue = value.issue;
    priority = Priority.fromApiValue(value.priority);
    safeNotify();
  }

  Future<void> _analyze(String imageId, String? description) async {
    suggesting = true;
    suggestion = null;
    suggestionMessage = null;
    safeNotify();
    try {
      suggestion = await _assist.analyze(imageId, description);
    } on AppException {
      suggestionMessage =
          'AI could not read the photo. Choose the issue yourself.';
    } finally {
      suggesting = false;
      safeNotify();
    }
  }

  Future<void> pickPhotos({String? description}) async {
    if (picking || _photos.length >= 3) return;
    picking = true;
    photoMessage = null;
    safeNotify();
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1440,
        imageQuality: 78,
        limit: 3 - _photos.length,
      );
      for (final file in files.take(3 - _photos.length)) {
        if (await file.length() > 5 * 1024 * 1024) {
          photoMessage = 'Choose photos smaller than 5 MB.';
          continue;
        }
        final bytes = await file.readAsBytes();
        final UploadedPhoto uploaded;
        try {
          uploaded = await _assist.uploadPhoto(bytes);
        } on AppException catch (error) {
          photoMessage = error.message;
          continue;
        }
        _photos.add(bytes);
        _uploaded.add(uploaded);
        if (suggestion == null && !suggesting) {
          await _analyze(uploaded.id, description);
        }
      }
    } on Exception {
      photoMessage = 'Could not open the selected photos.';
    } finally {
      picking = false;
      safeNotify();
    }
  }

  void chooseSubIssue(String? value) {
    subIssue = subIssue == value ? null : value;
    safeNotify();
  }

  void choosePriority(Priority value) {
    priority = value;
    safeNotify();
  }

  void setAnonymous(bool value) {
    anonymous = value;
    safeNotify();
  }

  /// Forget the category-specific choice when the category changes.
  void resetForCategory() {
    subIssue = null;
    safeNotify();
  }

  void removePhoto(int index) {
    if (state == ViewState.loading || picking) return;
    _photos.removeAt(index);
    _uploaded.removeAt(index);
    if (_photos.isEmpty) {
      suggestion = null;
      suggestionMessage = null;
    }
    safeNotify();
  }

  Future<void> submit(
    ComplaintCategory category,
    String title,
    String description, {
    String? location,
  }) async {
    if (state == ViewState.loading || picking || submitted != null) return;
    await run(() async {
      final result = await _repository.submit(
        category: category,
        title: title,
        description: description,
        subIssue: subIssue,
        priority: priority,
        location: location,
        anonymousToStaff: anonymous,
        imageUrls: [for (final item in _uploaded) item.url],
      );
      if (_photos.isNotEmpty) {
        try {
          await _photoStore.save(_ownerId, result.summary.id, _photos);
        } on AppException catch (error) {
          photoMessage = error.message;
        }
      }
      return result;
    }, onSuccess: (value) => submitted = value);
  }
}
