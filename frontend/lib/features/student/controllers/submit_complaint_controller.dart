import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/controllers/base_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/complaint_photo_store.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_category.dart';
import '../../../domain/enums/priority.dart';
import '../../../domain/models/complaint.dart';

final class SubmitComplaintController extends BaseController {
  SubmitComplaintController(this._repository, this._photoStore, this._ownerId);
  final ComplaintRepository _repository;
  final ComplaintPhotoStore _photoStore;
  final String _ownerId;
  final _picker = ImagePicker();
  final List<Uint8List> _photos = [];
  List<Uint8List> get photos => List.unmodifiable(_photos);
  Complaint? submitted;
  String? subIssue;
  Priority priority = Priority.medium;
  bool anonymous = false;
  String? photoMessage;
  bool picking = false;

  Future<void> pickPhotos() async {
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
        _photos.add(await file.readAsBytes());
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
