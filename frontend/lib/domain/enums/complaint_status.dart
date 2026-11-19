enum ComplaintStatus {
  pending('PENDING', 'Pending'),
  inProgress('IN_PROGRESS', 'In progress'),
  resolved('RESOLVED', 'Resolved'),
  rejected('REJECTED', 'Rejected');

  const ComplaintStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ComplaintStatus fromApiValue(String value) =>
      values.firstWhere((entry) => entry.apiValue == value);
}
