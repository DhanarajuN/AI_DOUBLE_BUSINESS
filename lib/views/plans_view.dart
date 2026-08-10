import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plan.dart';
import '../repositories/workspace_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/plans_view_model.dart';
import 'dashboard_view.dart' show fmtN, fmtTok;

class PlansView extends StatelessWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => PlansViewModel(ctx.read<WorkspaceRepository>()),
      child: const _PlansBody(),
    );
  }
}

class _PlansBody extends StatelessWidget {
  const _PlansBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlansViewModel>();
    final currency = vm.currency;
    final c = kCurrencies[currency]!;

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Text('Plans', style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Text(
              'A subscription, not a project. Every plan includes a conversation package; overage is billed per conversation.',
              style: AppFonts.body(size: 13, color: AppColors.ink2).copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
              child: Row(
                children: kCurrencies.entries.map((e) {
                  final on = currency == e.key;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => vm.setCurrency(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: on ? AppColors.card : null, borderRadius: BorderRadius.circular(9)),
                        child: Text(e.value.label, style: AppFonts.body(size: 12, weight: FontWeight.w600, color: on ? AppColors.ink : AppColors.ink2)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            ...kPlans.map((p) => _planCard(context, vm, p, c, currency)),
            const SizedBox(height: 8),
            Text(
              "First 14 days free · cancel any time · your brand, your channels.",
              textAlign: TextAlign.center,
              style: AppFonts.body(size: 11.5, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(BuildContext context, PlansViewModel vm, Plan p, Currency c, String currency) {
    final isCurrent = vm.currentPlanId == p.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.hot ? AppColors.accent : AppColors.line, width: p.hot ? 1.4 : 1),
        boxShadow: p.hot ? [BoxShadow(color: AppColors.accent.withOpacity(0.14), blurRadius: 20, offset: const Offset(0, 8))] : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isCurrent || p.hot)
            Positioned(
              top: -22,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: isCurrent ? AppColors.ok : AppColors.accent, borderRadius: BorderRadius.circular(100)),
                child: Text(isCurrent ? 'CURRENT PLAN' : 'MOST POPULAR', style: AppFonts.mono(size: 9, color: Colors.white, letterSpacing: 0.6)),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: AppFonts.display(size: 19)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(p.price != null ? '${c.symbol}${fmtN(p.price![currency]!)}' : "Let's talk", style: AppFonts.display(size: 27)),
                  if (p.price != null) Text(' / month', style: AppFonts.body(size: 12, color: AppColors.ink3)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.conversations > 0 ? '${fmtN(p.conversations)} conversations · ${fmtTok(p.tokens)} tokens included' : 'Committed volume · custom SLA',
                style: AppFonts.body(size: 12, color: AppColors.ink2),
              ),
              const SizedBox(height: 12),
              ...p.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(f.included ? Icons.check_circle_outline : Icons.remove_circle_outline, size: 16, color: f.included ? AppColors.ok : AppColors.line2),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f.label, style: AppFonts.body(size: 13, color: f.included ? AppColors.ink2 : AppColors.ink3))),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: isCurrent
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.line2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: null,
                        child: Text('Your current plan', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.ink3)),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.hot ? AppColors.accent : AppColors.paper2,
                          foregroundColor: p.hot ? Colors.white : AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _choosePlan(context, vm, p),
                        child: Text(p.price != null ? 'Switch to ${p.name}' : 'Contact sales', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _choosePlan(BuildContext context, PlansViewModel vm, Plan p) async {
    if (p.id == 'enterprise') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A solutions engineer would follow up — this demo saves nothing'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    await vm.choosePlan(p.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You're now on ${p.name}"), behavior: SnackBarBehavior.floating));
    }
  }
}
