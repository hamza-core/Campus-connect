import '../../../core/controllers/base_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint.dart';

final class ComplaintDetailController extends BaseController {
  ComplaintDetailController(this._repository, this.id);
  final ComplaintRepository _repository;
  final String id;
  Complaint? complaint;
  bool forbidden = false;
  bool saving = false;
  String? actionError;

  Future<void> load() => run(
    () async {
      try {
        return await _repository.detail(id);
      } on ForbiddenException {
        forbidden = true;
        rethrow;
      }
    },
    onSuccess: (value) {
      forbidden = false;
      complaint = value;
    },
  );

  /// Quietly re-fetches without a loading state; only notifies on a change.
  Future<void> refreshSilently() async {
    if (saving || state == ViewState.loading || complaint == null) return;
    try {
      final next = await _repository.detail(id);
      if (saving) return;
      final current = complaint!;
      if (next.rowVersion == current.rowVersion &&
          next.summary.status == current.summary.status &&
          next.timeline.length == current.timeline.length) {
        return;
      }
      complaint = next;
      safeNotify();
    } on Object {
      // Keep showing the last known data.
    }
  }

  Future<void> update(ComplaintStatus status, String remark) async {
    final current = complaint;
    if (current == null ||
        saving ||
        !current.allowedTransitions.contains(status)) {
      return;
    }
    final requiresRemark =
        status == ComplaintStatus.resolved ||
        status == ComplaintStatus.rejected;
    if (requiresRemark && remark.trim().isEmpty) {
      actionError = 'Enter a reason before saving.';
      safeNotify();
      return;
    }
    saving = true;
    actionError = null;
    safeNotify();
    try {
      complaint = await _repository.updateStatus(
        id: id,
        rowVersion: current.rowVersion,
        status: status,
        remark: remark.trim().isEmpty ? null : remark.trim(),
      );
    } on ConflictException catch (error) {
      actionError = error.message;
      await load();
    } on ForbiddenException {
      forbidden = true;
    } on AppException catch (error) {
      actionError = error.message;
    } finally {
      saving = false;
      safeNotify();
    }
  }

  /// Student rates a resolved complaint (once).
  Future<void> rate(int rating, String comment) async {
    if (saving || complaint == null) return;
    saving = true;
    actionError = null;
    safeNotify();
    try {
      complaint = await _repository.submitFeedback(
        id: id,
        rating: rating,
        comment: comment,
      );
    } on ConflictException catch (error) {
      actionError = error.message;
      await load();
    } on ForbiddenException {
      forbidden = true;
    } on AppException catch (error) {
      actionError = error.message;
    } finally {
      saving = false;
      safeNotify();
    }
  }

  Future<bool> addRemark(String text) async {
    if (saving || complaint == null) return false;
    final message = text.trim();
    if (message.isEmpty) {
      actionError = 'Enter a remark before posting.';
      safeNotify();
      return false;
    }
    saving = true;
    actionError = null;
    safeNotify();
    try {
      await _repository.addRemark(id, message);
      await load();
      if (errorMessage != null && !forbidden) {
        actionError = 'Remark posted. Reload the complaint to see it.';
      }
      return true;
    } on ForbiddenException {
      forbidden = true;
      return false;
    } on AppException catch (error) {
      actionError = error.message;
      return false;
    } finally {
      saving = false;
      safeNotify();
    }
  }
}
