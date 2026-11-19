enum ComplaintCategory {
  cafeteria('CAFETERIA'),
  library('LIBRARY'),
  labsAndIt('LAB_IT'),
  academic('ACADEMIC');

  const ComplaintCategory(this.apiValue);
  final String apiValue;

  static ComplaintCategory fromApiValue(String value) =>
      values.firstWhere((entry) => entry.apiValue == value);

  /// Example issues from the competition brief (identical to the server's list).
  List<String> get subIssues => switch (this) {
    cafeteria => const [
      'Poor food quality or hygiene',
      'High food prices',
      'Limited food variety',
      'Unprofessional staff behaviour or poor service',
    ],
    library => const [
      'Insufficient or outdated books and learning resources',
      'Librarian availability or staff behaviour',
      'Library opening and closing hours',
      'Insufficient seating or study space',
    ],
    labsAndIt => const [
      'Non-functional computers',
      'Internet connectivity issues',
      'Projector or multimedia equipment problems',
      'Missing or unavailable software',
    ],
    academic => const [
      'Teachers arriving late to lectures',
      'Unavailability of lecture notes or learning materials',
      'Inadequate explanation of course topics',
      'Classroom management or discipline issues',
    ],
  };
}
