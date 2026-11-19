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
}
