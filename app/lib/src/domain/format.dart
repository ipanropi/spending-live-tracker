/// Small formatting helpers, kept in-house instead of pulling in `intl` so the
/// app stays small. Everything reads the way the dashboard shows it:
/// "RM 1,234.56", "8 Nov", "Sun, 8 Nov, 2:15 pm".
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Formats sen as ringgit: 123456 → "RM 1,234.56". Negative amounts get a real minus sign.
String rm(int cents) {
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  final sen = (abs % 100).toString().padLeft(2, '0');
  return '${cents < 0 ? '−' : ''}RM $grouped.$sen';
}

/// "8 Nov"
String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "2:15 pm"
String time12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

/// "Sun, 8 Nov, 2:15 pm"
String weekdayDateTime(DateTime d) => '${_weekdays[d.weekday - 1]}, ${dayMonth(d)}, ${time12(d)}';

/// "1 time", "3 times"
String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// "7 Nov – 6 Dec", with the year added when the cycle ends in a different year from [now].
String cycleLabel(DateTime start, {required DateTime now}) {
  final last = DateTime(start.year, start.month + 1, start.day - 1);
  final year = last.year != now.year ? ' ${last.year}' : '';
  return '${dayMonth(start)} – ${dayMonth(last)}$year';
}
