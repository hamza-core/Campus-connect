enum ComplaintStatus {
  pending('PENDING'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  rejected('REJECTED');

  const ComplaintStatus(this.apiValue);
  final String apiValue;

  static ComplaintStatus fromApiValue(String value) =>
      values.firstWhere((entry) => entry.apiValue == value);
}
