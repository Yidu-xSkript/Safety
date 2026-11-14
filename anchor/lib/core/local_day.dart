// A "day" is a calendar date with no time of day, held as UTC midnight so == and map lookups behave.
// The day starts at 04:00, not midnight: a 01:30 check-in belongs to the evening before. Mirrors docs/SCHEMA.md.

const kDayStartHour = 4;

DateTime dayOf(int year, int month, int day) => DateTime.utc(year, month, day);

/// The local day `now` belongs to.
// ponytail: subtracts an absolute duration, so the two nights a year the clock changes can be an hour off.
DateTime localDate(DateTime now, {int dayStartHour = kDayStartHour}) {
  final s = now.subtract(Duration(hours: dayStartHour));
  return DateTime.utc(s.year, s.month, s.day);
}

DateTime addDays(DateTime day, int n) => DateTime.utc(day.year, day.month, day.day + n);

/// `2026-11-14`. Stable key for storage and JSON.
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
