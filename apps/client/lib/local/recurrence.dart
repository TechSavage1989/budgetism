/// Calendar dates only. UTC arithmetic prevents daylight-saving shifts; the
/// original day stays the anchor after short months and non-leap years.
class Recurrence {
  static const frequencies = ['weekly', 'fortnightly', 'monthly', 'yearly'];

  static DateTime parse(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Choose a valid date.');
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final date = DateTime.utc(year, month, day);
    if (year < 1900 || year > 9999 || date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Choose a date between 1900 and 9999.');
    }
    return date;
  }

  static String format(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String today() => format(DateTime.now());
  static String label(String frequency) => switch (frequency) {
    'weekly' => 'Weekly', 'fortnightly' => 'Every two weeks',
    'monthly' => 'Monthly', 'yearly' => 'Yearly',
    _ => throw const FormatException('Unsupported recurrence.'),
  };

  static String? at(String startDate, String frequency, int index) {
    if (!frequencies.contains(frequency) || index < 0 || index > 500000) {
      throw const FormatException('Invalid schedule occurrence.');
    }
    final start = parse(startDate);
    DateTime result;
    if (frequency == 'weekly' || frequency == 'fortnightly') {
      result = start.add(Duration(days: index * (frequency == 'weekly' ? 7 : 14)));
    } else {
      final monthIndex = start.year * 12 + start.month - 1 + index * (frequency == 'yearly' ? 12 : 1);
      final year = monthIndex ~/ 12;
      if (year > 9999) return null;
      final month = monthIndex % 12 + 1;
      final lastDay = DateTime.utc(year, month + 1, 0).day;
      result = DateTime.utc(year, month, start.day > lastDay ? lastDay : start.day);
    }
    return result.year > 9999 ? null : format(result);
  }

  /// Largest occurrence index on or before a date, or -1 before the first due.
  static int lastIndex(String startDate, String frequency, String through) {
    final start = parse(startDate);
    final end = parse(through);
    if (!frequencies.contains(frequency)) throw const FormatException('Unsupported recurrence.');
    if (end.isBefore(start)) return -1;
    if (frequency == 'weekly' || frequency == 'fortnightly') {
      return end.difference(start).inDays ~/ (frequency == 'weekly' ? 7 : 14);
    }
    var index = frequency == 'yearly' ? end.year - start.year
        : (end.year - start.year) * 12 + end.month - start.month;
    if (at(startDate, frequency, index)!.compareTo(through) > 0) index--;
    return index;
  }
}
