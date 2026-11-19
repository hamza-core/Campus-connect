import '../../domain/models/complaint.dart';

final class MockComplaintRecord {
  MockComplaintRecord(this.ownerId, this.complaint);

  final String ownerId;
  Complaint complaint;
}
