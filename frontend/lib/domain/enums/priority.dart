enum Priority {
  low('LOW', 'Low'),
  medium('MEDIUM', 'Medium'),
  high('HIGH', 'High');

  const Priority(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static Priority fromApiValue(String? value) => values.firstWhere(
    (entry) => entry.apiValue == value,
    orElse: () => Priority.medium,
  );
}
