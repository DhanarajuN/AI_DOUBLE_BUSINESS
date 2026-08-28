String fmtDateDMY(DateTime dt) {
  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String fmtTimeOnly(DateTime dt) {
  final local = dt.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $ampm';
}

String fmtDateTimeDMY(DateTime dt) => '${fmtDateDMY(dt)} ${fmtTimeOnly(dt)}';

final _bareTimePattern = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?$');

// A "Time" field's raw value can come back either as a full ISO
// date+time string or as a bare clock string like "10:00" / "6:30 PM" with
// no date at all — DateTime.tryParse only handles the former. onDate
// supplies the calendar day to attach the parsed hour/minute to; defaults
// to today when the caller only needs the time-of-day itself.
DateTime? parseFlexibleTime(String raw, {DateTime? onDate}) {
  final iso = DateTime.tryParse(raw)?.toLocal();
  if (iso != null) return iso;

  final match = _bareTimePattern.firstMatch(raw.trim());
  if (match == null) return null;
  var hour = int.tryParse(match.group(1)!) ?? -1;
  final minute = int.tryParse(match.group(2)!) ?? -1;
  final second = int.tryParse(match.group(3) ?? '0') ?? 0;
  final ampm = match.group(4)?.toUpperCase();
  if (ampm == 'PM' && hour < 12) hour += 12;
  if (ampm == 'AM' && hour == 12) hour = 0;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

  final base = onDate ?? DateTime.now();
  return DateTime(base.year, base.month, base.day, hour, minute, second);
}
