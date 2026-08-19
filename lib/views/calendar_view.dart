import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/calendar_view_model.dart';
import 'dashboard_view.dart'
    show fmtN, initialsOf, orderData, orderStatusOf, orderStatusColor, firstNonEmpty, parseDate, showBookingDetail;

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _mons = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _dows = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

DateTime? _bookingDateTime(Map<String, dynamic> booking) {
  final data = orderData(booking);
  final raw = firstNonEmpty(data, const [
    'Booking Date',
    'Appointment Date',
    'Scheduled Date',
    'Booking Time',
    'Appointment Time',
    'Date',
    'Time',
  ]);
  if (raw != null) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return parseDate(booking['createdAt']);
}

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CalendarViewModel(
          ctx.read<WorkspaceRepository>(), ctx.read<SessionStorage>(), ctx.read<ApiClient>()),
      child: const _CalendarBody(),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody();

  Map<DateTime, List<Map<String, dynamic>>> _bookingsByDay(List<Map<String, dynamic>> bookings) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final b in bookings) {
      final dt = _bookingDateTime(b);
      if (dt == null) continue;
      final key = DateTime(dt.year, dt.month, dt.day);
      (map[key] ??= []).add(b);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CalendarViewModel>();
    if (vm.business == null) return const SizedBox();

    final month = vm.month;
    final map = _bookingsByDay(vm.bookings);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startDow = firstOfMonth.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthDays = DateTime(month.year, month.month, 0).day;

    final monthBookings = vm.bookings.where((b) {
      final dt = _bookingDateTime(b);
      return dt != null && dt.year == month.year && dt.month == month.month;
    }).toList();
    final bookedDays = monthBookings.map((b) => _bookingDateTime(b)!.day).toSet();
    final byDayCount = <int, int>{};
    for (final b in monthBookings) {
      final d = _bookingDateTime(b)!.day;
      byDayCount[d] = (byDayCount[d] ?? 0) + 1;
    }
    int? busiestDay;
    byDayCount.forEach((d, c) {
      if (busiestDay == null || c > byDayCount[busiestDay]!) busiestDay = d;
    });

    final cells = <_Cell>[];
    for (var i = 0; i < 42; i++) {
      final idx = i - startDow;
      int dayNum;
      int cy = month.year, cm = month.month;
      bool other = false;
      if (idx < 0) {
        dayNum = prevMonthDays + idx + 1;
        cm -= 1;
        if (cm < 1) {
          cm = 12;
          cy -= 1;
        }
        other = true;
      } else if (idx >= daysInMonth) {
        dayNum = idx - daysInMonth + 1;
        cm += 1;
        if (cm > 12) {
          cm = 1;
          cy += 1;
        }
        other = true;
      } else {
        dayNum = idx + 1;
      }
      final date = DateTime(cy, cm, dayNum);
      final bks = map[date] ?? const [];
      cells.add(_Cell(date: date, other: other, bookings: bks, isToday: date == today, isPast: date.isBefore(today)));
    }
    final rows = ((startDow + daysInMonth) / 7).ceil();
    final visibleCells = cells.take(rows * 7).toList();
    final futureOpen = visibleCells.where((c) => !c.other && !c.isPast && c.bookings.isEmpty).length;

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Calendar', style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Text('Every booking taken through your AI Double, by day.', style: AppFonts.body(size: 13, color: AppColors.ink2)),
            const SizedBox(height: 14),
            Row(
              children: [
                _sumTile(fmtN(monthBookings.length), 'this month'),
                _sumTile(fmtN(bookedDays.length), 'days booked'),
                _sumTile(fmtN(futureOpen), 'days open'),
                _sumTile(busiestDay != null ? '$busiestDay ${_mons[month.month - 1]}' : '—', 'busiest'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_months[month.month - 1]} ${month.year}', style: AppFonts.display(size: 16)),
                      Row(
                        children: [
                          _navBtn(Icons.chevron_left, () => vm.shift(-1)),
                          TextButton(onPressed: vm.goToday, child: Text('Today', style: AppFonts.body(size: 12, weight: FontWeight.w600, color: AppColors.accent))),
                          _navBtn(Icons.chevron_right, () => vm.shift(1)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: _dows.map((d) => Expanded(child: Center(child: Text(d, style: AppFonts.mono(size: 10.5))))).toList()),
                  const SizedBox(height: 4),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: visibleCells.map((c) => _dayCell(vm, c)).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(AppColors.accent, 'Booked'),
                      const SizedBox(width: 16),
                      _legend(AppColors.ok.withOpacity(0.65), 'Open'),
                      const SizedBox(width: 16),
                      _legendRing('Today'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _detail(context, vm, map, today),
          ],
        ),
      ),
    );
  }

  Widget _sumTile(String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Column(
            children: [
              Text(value, style: AppFonts.display(size: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: AppFonts.body(size: 9.5, color: AppColors.ink3)),
            ],
          ),
        ),
      );

  Widget _navBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.line2)),
          child: Icon(icon, size: 18, color: AppColors.ink),
        ),
      );

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: AppFonts.body(size: 11, color: AppColors.ink2)),
        ],
      );

  Widget _legendRing(String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 2))),
          const SizedBox(width: 5),
          Text(label, style: AppFonts.body(size: 11, color: AppColors.ink2)),
        ],
      );

  Widget _dayCell(CalendarViewModel vm, _Cell c) {
    final selected = vm.selected != null && vm.selected == c.date;
    Color? bg;
    if (c.bookings.isNotEmpty) {
      bg = AppColors.accentSoft;
    } else if (!c.other && !c.isPast) {
      bg = AppColors.paper;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => vm.select(c.date),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          border: selected ? Border.all(color: AppColors.accent) : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c.isToday ? AppColors.accent : null),
              child: Text(
                '${c.date.day}',
                style: AppFonts.body(
                  size: 12.5,
                  weight: c.bookings.isNotEmpty || c.isToday ? FontWeight.w700 : FontWeight.w500,
                  color: c.isToday
                      ? Colors.white
                      : c.other
                          ? AppColors.ink3.withOpacity(0.5)
                          : c.bookings.isNotEmpty
                              ? AppColors.accent
                              : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 1),
            if (c.bookings.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                height: 14,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(100)),
                alignment: Alignment.center,
                child: Text('${c.bookings.length}', style: AppFonts.mono(size: 8.5, color: Colors.white)),
              )
            else if (!c.other && !c.isPast)
              Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.ok.withOpacity(0.65), shape: BoxShape.circle))
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, CalendarViewModel vm, Map<DateTime, List<Map<String, dynamic>>> map, DateTime today) {
    if (vm.selected == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Text(
          'Tap a day to see its bookings. Blue = booked, dot = open, ring = today.',
          textAlign: TextAlign.center,
          style: AppFonts.body(size: 12.5, color: AppColors.ink3).copyWith(height: 1.6),
        ),
      );
    }
    final sel = vm.selected!;
    final bks = (map[sel] ?? const <Map<String, dynamic>>[]).toList()
      ..sort((a, b) => (_bookingDateTime(a) ?? sel).compareTo(_bookingDateTime(b) ?? sel));
    final isPast = sel.isBefore(today);
    const dowFull = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${dowFull[sel.weekday - 1]}, ${sel.day} ${_mons[sel.month - 1]} ${sel.year}', style: AppFonts.display(size: 15)),
                    Text(
                      bks.isNotEmpty ? '${bks.length} booking${bks.length > 1 ? 's' : ''}' : (isPast ? 'No bookings' : 'Open — no bookings yet'),
                      style: AppFonts.body(size: 12, color: bks.isEmpty && !isPast ? AppColors.ok : AppColors.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (bks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                isPast ? 'This day had no bookings.' : 'This slot is free. Your AI Double can take bookings here around the clock.',
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 12.5, color: AppColors.ink3).copyWith(height: 1.5),
              ),
            )
          else
            ...bks.map((b) {
              final data = orderData(b);
              final name = firstNonEmpty(data, const ['Customer Name', 'Name', 'Full Name']) ?? 'Customer';
              final service = firstNonEmpty(data, const ['Service Name', 'Service', 'Item Name', 'Item']) ?? '';
              final status = orderStatusOf(b);
              final dt = _bookingDateTime(b);
              return InkWell(
                onTap: () => showBookingDetail(context, b),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        child: Text(dt != null ? _timeOf(dt) : '—', style: AppFonts.mono(size: 11, color: AppColors.ink2)),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(initialsOf(name), style: AppFonts.body(size: 10.5, weight: FontWeight.w700, color: AppColors.accent)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppFonts.body(size: 13, weight: FontWeight.w600, color: AppColors.ink)),
                            if (service.isNotEmpty) Text(service, style: AppFonts.body(size: 11, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: orderStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                          child: Text(status, style: AppFonts.mono(size: 9.5, color: orderStatusColor(status))),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _timeOf(DateTime t) {
    var h = t.hour;
    final ap = h < 12 ? 'AM' : 'PM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} $ap';
  }
}

class _Cell {
  final DateTime date;
  final bool other;
  final List<Map<String, dynamic>> bookings;
  final bool isToday;
  final bool isPast;
  const _Cell({required this.date, required this.other, required this.bookings, required this.isToday, required this.isPast});
}
