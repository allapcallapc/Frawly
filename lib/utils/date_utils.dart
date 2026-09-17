/// Today's date in the device's local timezone, with no time component -
/// used as the New filling form's default so it never drifts to UTC's
/// "today" for users west of Greenwich late at night.
DateTime localToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Formats a date-only [DateTime] as the `date` column expects
/// ("YYYY-MM-DD"), ignoring any time component.
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date for display (e.g. "Jan 5, 2026"), or [emptyLabel] when
/// [date] is null (vacant containers have no date).
String formatDisplayDate(DateTime? date, {String emptyLabel = '—'}) {
  if (date == null) return emptyLabel;
  return '${_monthAbbreviations[date.month - 1]} ${date.day}, ${date.year}';
}
