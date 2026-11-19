enum ComplaintCategory {
  cafeteria('CAFETERIA'),
  library('LIBRARY'),
  labsAndIt('LAB_IT'),
  academic('ACADEMIC');

  const ComplaintCategory(this.apiValue);
  final String apiValue;

  static ComplaintCategory fromApiValue(String value) =>
      values.firstWhere((entry) => entry.apiValue == value);
}
