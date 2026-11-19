import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static String date(DateTime timestamp, {String? locale}) =>
      DateFormat.yMMMd(locale).format(timestamp.toLocal());
}
