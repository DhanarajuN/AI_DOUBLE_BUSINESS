import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/channel.dart';
import '../models/industry.dart';
import '../models/plan.dart';
import '../repositories/workspace_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../widgets/business_icons.dart';
import 'home_shell_view.dart';
import 'plans_view.dart';

String fmtN(num n) => n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

String fmtTok(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
  return n.round().toString();
}

String timeAgo(DateTime t) {
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return 'just now';
  final m = s ~/ 60;
  if (m < 60) return '${m}m ago';
  final h = m ~/ 60;
  if (h < 24) return '${h}h ago';
  final d = h ~/ 24;
  if (d < 7) return '${d}d ago';
  return '${d ~/ 7}w ago';
}

String initialsOf(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  final a = p.isNotEmpty && p[0].isNotEmpty ? p[0][0] : '';
  final b = p.length > 1 && p[1].isNotEmpty ? p[1][0] : '';
  return (a + b).toUpperCase();
}

Color statusColor(BookingStatus s) {
  switch (s) {
    case BookingStatus.confirmed:
      return AppColors.accent;
    case BookingStatus.completed:
      return AppColors.ok;
    case BookingStatus.pending:
      return AppColors.amber;
    case BookingStatus.noshow:
      return AppColors.ink3;
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardViewModel(ctx.read<WorkspaceRepository>()),
      child: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final biz = vm.business;
    if (biz == null) return const SizedBox();

    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final ind = industryById(biz.industryId);
    final plan = planById(biz.planId);
    final c = kCurrencies[vm.currency]!;
    final bks = vm.bookings;
    final totalTok = vm.usageIn + vm.usageOut;
    final monthTok = vm.usageDaily.fold<int>(0, (a, b) => a + b);
    final now = DateTime.now();
    final bksMonth = bks.where((b) => b.time.year == now.year && b.time.month == now.month).length;
    final upcoming = bks.where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).length;
    final completed = bks.where((b) => b.status == BookingStatus.completed).length;
    final chanTally = <String, int>{};
    for (final b in bks) {
      chanTally[b.channelId] = (chanTally[b.channelId] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _hero(biz.name, biz.owner, greet, ind, plan, c),
              const SizedBox(height: 14),
              _kpiGrid(context, bks.length, totalTok, plan, vm.docs.length),
              _sectionHeader('Bookings', 'Calendar →', () => _goTab(context, 1)),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _stat(fmtN(bksMonth), 'this month'),
                        _stat(fmtN(upcoming), 'upcoming'),
                        _stat(fmtN(completed), 'completed'),
                      ],
                    ),
                    if (chanTally.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: chanTally.entries.map((e) {
                          final ch = channelById(e.key);
                          return _pill('${ch.name} · ${e.value}', businessIcon(ch.iconKey));
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (bks.isEmpty)
                      _empty('No bookings yet.')
                    else
                      ...bks.take(5).map((b) => _bookingRow(b)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.paper2,
                          side: BorderSide(color: AppColors.line2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        onPressed: () async {
                          final bk = await vm.simulateBooking();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${bk.customerName} just booked · ${bk.service}'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        icon: Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.ink),
                        label: Text('Simulate an incoming booking', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                      ),
                    ),
                  ],
                ),
              ),
              _sectionHeader('AI usage', '${fmtN(vm.usageCalls)} calls', null),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fmtTok(monthTok), style: AppFonts.display(size: 24)),
                              Text('tokens this period', style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('In ${fmtTok(vm.usageIn)}', style: AppFonts.mono(size: 10.5)),
                            Text('Out ${fmtTok(vm.usageOut)}', style: AppFonts.mono(size: 10.5)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _barChart(vm.usageDaily),
                    const SizedBox(height: 12),
                    _meterLine('Included in ${plan.name}', plan.tokens > 0 ? '${fmtTok(totalTok)} / ${fmtTok(plan.tokens)}' : 'Unlimited'),
                    const SizedBox(height: 6),
                    _meter(totalTok, plan.tokens),
                  ],
                ),
              ),
              _sectionHeader('Your plan', 'Manage →', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansView()))),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.name, style: AppFonts.display(size: 20)),
                              Text(
                                plan.price != null ? '${c.symbol}${fmtN(plan.price![vm.currency]!)} / month' : 'Custom pricing',
                                style: AppFonts.body(size: 12, color: AppColors.ink3),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansView())),
                          child: Text(plan.id == 'pro' || plan.id == 'enterprise' ? 'Manage' : 'Upgrade', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _meterLine('Conversations', plan.conversations > 0 ? '${fmtN(bks.length)} / ${fmtN(plan.conversations)}' : fmtN(bks.length)),
                    const SizedBox(height: 6),
                    _meter(bks.length, plan.conversations),
                  ],
                ),
              ),
              _sectionHeader('Files uploaded', 'Manage →', () => _goTab(context, 3)),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.docs.isEmpty)
                      _empty('No files yet. Add your policies, price lists or FAQs so the agent answers from them.')
                    else
                      ...vm.docs.take(4).map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(9)),
                                  alignment: Alignment.center,
                                  child: Icon(businessIcon(d.isFile ? 'file' : 'doc'), size: 17, color: AppColors.accent),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                                      Text(d.meta, style: AppFonts.body(size: 11, color: AppColors.ink3)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.paper2,
                          side: BorderSide(color: AppColors.line2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                        onPressed: () => _goTab(context, 3),
                        icon: Icon(Icons.upload_outlined, size: 16, color: AppColors.ink),
                        label: Text('Add documents', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goTab(BuildContext context, int i) {
    final state = context.findAncestorStateOfType<State<HomeShellView>>();
    (state as dynamic)?.goToTab(i);
  }

  Widget _hero(String name, String owner, String greet, Industry ind, Plan plan, Currency c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.chromeGradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.isNotEmpty ? '$greet, ${owner.split(' ').first}' : greet,
                      style: AppFonts.mono(size: 10.5, color: AppColors.chromeTx, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(name, style: AppFonts.display(size: 21, color: Colors.white)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.chromeLine)),
                child: Text(plan.name, style: AppFonts.mono(size: 10, color: Colors.white, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _heroTag(businessIcon(ind.iconKey), ind.name),
              _heroTag(Icons.public_outlined, c.label),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTag(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent2),
          const SizedBox(width: 5),
          Text(text, style: AppFonts.body(size: 12, color: AppColors.chromeTx)),
        ],
      );

  Widget _kpiGrid(BuildContext context, int bookings, int tokens, Plan plan, int docCount) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _kpi(Icons.calendar_month_outlined, fmtN(bookings), 'Bookings', AppColors.accent, AppColors.accentSoft, () => _goTab(context, 1)),
        _kpi(Icons.bar_chart_outlined, fmtTok(tokens), 'AI tokens used', AppColors.ok, const Color(0x190E8A5F), null),
        _kpi(Icons.local_offer_outlined, plan.name, 'Current plan', AppColors.amber, const Color(0x19B45309), () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansView()))),
        _kpi(Icons.description_outlined, fmtN(docCount), 'Files uploaded', const Color(0xFF4F46E5), const Color(0x194F46E5), () => _goTab(context, 3)),
      ],
    );
  }

  Widget _kpi(IconData icon, String value, String label, Color color, Color bg, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(value, style: AppFonts.display(size: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: AppFonts.body(size: 11, color: AppColors.ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 2, right: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppFonts.display(size: 17)),
          if (onTap != null) GestureDetector(onTap: onTap, child: Text(action, style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.accent)))
          else Text(action, style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: child,
      );

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppFonts.display(size: 16)),
              Text(label, style: AppFonts.body(size: 10.5, color: AppColors.ink3)),
            ],
          ),
        ),
      );

  Widget _pill(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.ink3),
            const SizedBox(width: 5),
            Text(text, style: AppFonts.body(size: 11.5, color: AppColors.ink2)),
          ],
        ),
      );

  Widget _bookingRow(Booking b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(initialsOf(b.customerName), style: AppFonts.body(size: 11.5, weight: FontWeight.w700, color: AppColors.accent)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                  Text('${b.service} · ${channelById(b.channelId).name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: statusColor(b.status).withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                  child: Text(bookingStatusLabel(b.status), style: AppFonts.mono(size: 9.5, color: statusColor(b.status))),
                ),
                const SizedBox(height: 3),
                Text(timeAgo(b.time), style: AppFonts.body(size: 10.5, color: AppColors.ink3)),
              ],
            ),
          ],
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, textAlign: TextAlign.center, style: AppFonts.body(size: 12.5, color: AppColors.ink3)),
      );

  Widget _barChart(List<int> arr) {
    final max = arr.isEmpty ? 1 : arr.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(arr.length, (i) {
          final h = (arr[i] / max * 100).clamp(6, 100).toDouble();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FractionallySizedBox(
                heightFactor: h / 100,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: i == arr.length - 1 ? AppColors.accent : AppColors.line2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _meterLine(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppFonts.body(size: 11.5, color: AppColors.ink2)),
          Text(value, style: AppFonts.body(size: 11.5, color: AppColors.ink2)),
        ],
      );

  Widget _meter(num used, num cap) {
    final pct = cap <= 0 ? 0.22 : (used / cap).clamp(0.0, 1.0);
    final color = pct >= 0.9 ? AppColors.danger : pct >= 0.7 ? AppColors.amber : AppColors.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: AppColors.paper2, valueColor: AlwaysStoppedAnimation(color)),
    );
  }
}
