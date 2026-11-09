/// Small formatting helpers, kept in-house instead of pulling in `intl` so the
/// app stays small. Everything reads the way the dashboard shows it:
/// "RM 1,234.56", "8 Nov", "Today, 2:15 pm", "Updated 3 min ago".
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Formats sen as ringgit: 123456 → "RM 1,234.56". Negative amounts get a real minus sign.
String rm(int cents) {
  final (sign, number) = rmParts(cents);
  return '${sign}RM $number';
}

/// An amount split for display, so "RM" can be drawn smaller than the digits:
/// -123456 → ('−', '1,234.56').
(String, String) rmParts(int cents) {
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  final sen = (abs % 100).toString().padLeft(2, '0');
  return (cents < 0 ? '−' : '', '$grouped.$sen');
}

/// "8 Nov"
String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "2:15 pm"
String time12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

/// "Today", "Yesterday", or "Fri, 6 Nov" (with the year when it isn't this year).
/// Recent days are easier to recognise by name than by date.
String dayLabel(DateTime d, {required DateTime now}) {
  final days = _calendarDays(d, now);
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  final label = '${_weekdays[d.weekday - 1]}, ${dayMonth(d)}';
  return d.year == now.year ? label : '$label ${d.year}';
}

/// "Today, 2:15 pm", "Yesterday, 9:05 am", "Fri, 6 Nov, 2:15 pm"
String whenLabel(DateTime d, {required DateTime now}) => '${dayLabel(d, now: now)}, ${time12(d)}';

/// How fresh the data is: "Updated just now", "Updated 5 min ago", then the
/// time ("Updated 9:05 am") and, on earlier days, the day too.
String updatedLabel(DateTime fetched, {required DateTime now}) {
  final minutes = now.difference(fetched).inMinutes;
  if (minutes < 1) return 'Updated just now';
  if (minutes < 60) return 'Updated $minutes min ago';
  if (_calendarDays(fetched, now) == 0) return 'Updated ${time12(fetched)}';
  return 'Updated ${whenLabel(fetched, now: now)}';
}

/// "since Mon, 2 Nov", "since yesterday", "since today": when a running total started.
String sinceLabel(DateTime start, {required DateTime now}) => switch (_calendarDays(start, now)) {
  0 => 'since today',
  1 => 'since yesterday',
  _ => 'since ${dayLabel(start, now: now)}',
};

/// "1 time", "3 times"
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Merchant names arrive in capitals ("KANTIN PEJABAT", "GRAB*RIDE"), which are
/// hard to read; this shows them in normal case ("Kantin Pejabat", "Grab Ride").
/// Short codes without vowels (KTM, KFC) and anything with a digit stay as they
/// are. Names that already have lowercase letters are left alone. Display only:
/// grouping and categories still use the name as Wise sent it.
String displayName(String raw) {
  if (raw.contains(RegExp('[a-z]'))) return raw;
  return raw
      .replaceAll('*', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => word.contains(RegExp('[0-9]')) || (word.length <= 3 && !word.contains(RegExp('[AEIOU]')))
            ? word
            : word[0] + word.substring(1).toLowerCase(),
      )
      .join(' ');
}

/// "7 Nov – 6 Dec", with the year added when the cycle ends in a different year from [now].
String cycleLabel(DateTime start, {required DateTime now}) {
  final last = DateTime(start.year, start.month + 1, start.day - 1);
  final year = last.year != now.year ? ' ${last.year}' : '';
  return '${dayMonth(start)} – ${dayMonth(last)}$year';
}

int _calendarDays(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
