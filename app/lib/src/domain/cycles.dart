/// Pay cycles and paydays.
///
/// The monthly summary runs from the 7th to the 6th. "Left" counts down to the
/// next payday instead (the 7th or the 22nd), because Wise is topped up on both.
/// Weeks are normal calendar weeks, Monday to Sunday.
library;

/// The monthly summary starts on this day.
const int cycleStartDay = 7;

/// Days of the month you get paid and top up Wise.
const List<int> paydays = [7, 22];

/// How many monthly cycles to fetch from Wise (this one plus five earlier).
const int cyclesToLoad = 6;

/// Malaysia time has no daylight saving: always UTC+8.
const Duration _myt = Duration(hours: 8);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [a] to [b]. Safe across daylight-saving changes.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Start of the monthly cycle containing [d], in [d]'s own time zone.
DateTime cycleStart(DateTime d) {
  final s = DateTime(d.year, d.month, cycleStartDay);
  return d.isBefore(s) ? DateTime(d.year, d.month - 1, cycleStartDay) : s;
}

/// The day after a cycle's last day: the next cycle's start.
DateTime cycleEnd(DateTime start) => DateTime(start.year, start.month + 1, start.day);

/// The next payday after today. On a payday itself it's the following one,
/// since you top up that day.
DateTime nextPayday(DateTime now) {
  final today = dateOnly(now);
  final candidates = [
    for (final month in [0, 1])
      for (final day in paydays) DateTime(today.year, today.month + month, day),
  ]..sort();
  return candidates.firstWhere((d) => d.isAfter(today));
}

/// Monday of the week containing [now], at midnight.
DateTime weekStart(DateTime now) => DateTime(now.year, now.month, now.day - (now.weekday - 1));

/// Start of the Wise statement window: the start of the cycle [cyclesToLoad] - 1
/// cycles back, at midnight Malaysia time, as a UTC instant. Worked out in
/// Malaysia time explicitly because the device may be set to another zone.
DateTime statementWindowStart(DateTime now) {
  final m = now.toUtc().add(_myt); // Malaysian wall-clock time, held in a UTC DateTime
  var s = DateTime.utc(m.year, m.month, cycleStartDay);
  if (m.isBefore(s)) s = DateTime.utc(m.year, m.month - 1, cycleStartDay);
  s = DateTime.utc(s.year, s.month - (cyclesToLoad - 1), cycleStartDay);
  return s.subtract(_myt);
}
