import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/dashboard_view_model.dart';
import 'dashboard_view.dart'
    show fmtN, fmtDateTime, orderData, orderTitle, orderStatusOf, orderStatusColor, parseDate, showOrderDetail;

enum _Period { week, month, total, custom }

class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardViewModel(
          ctx.read<WorkspaceRepository>(), ctx.read<SessionStorage>(), ctx.read<ApiClient>()),
      child: const _OrdersBody(),
    );
  }
}

class _OrdersBody extends StatefulWidget {
  const _OrdersBody();

  @override
  State<_OrdersBody> createState() => _OrdersBodyState();
}

class _OrdersBodyState extends State<_OrdersBody> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _Period _period = _Period.total;
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesQuery(Map<String, dynamic> order, String query) {
    if (query.isEmpty) return true;
    final data = orderData(order);
    final haystack = [orderTitle(order, data), ...data.values.map((v) => v.toString())]
        .join(' ')
        .toLowerCase();
    return haystack.contains(query);
  }

  bool _matchesPeriod(Map<String, dynamic> order) {
    final created = parseDate(order['createdAt']);
    if (created == null) return _period == _Period.total;
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        return now.difference(created).inDays < 7;
      case _Period.month:
        return created.year == now.year && created.month == now.month;
      case _Period.total:
        return true;
      case _Period.custom:
        final range = _customRange;
        if (range == null) return true;
        final day = DateTime(created.year, created.month, created.day);
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        return !day.isBefore(start) && !day.isAfter(end);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange:
          _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      builder: (ctx, child) => Theme(data: _rangePickerTheme(ctx), child: child!),
    );
    if (picked == null) return;
    setState(() {
      _customRange = picked;
      _period = _Period.custom;
    });
  }

  ThemeData _rangePickerTheme(BuildContext context) {
    final base = Theme.of(context);
    Color onDay(Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) return Colors.white;
      if (states.contains(WidgetState.disabled)) return AppColors.ink3.withOpacity(0.4);
      return AppColors.ink;
    }

    Color? dayBg(Set<WidgetState> states) => states.contains(WidgetState.selected) ? AppColors.accent : null;

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        primaryContainer: AppColors.accentSoft,
        onPrimaryContainer: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.card,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.ink3,
        outline: AppColors.line2,
        surfaceContainerHigh: AppColors.paper2,
      ),
      textTheme: base.textTheme.apply(fontFamily: AppFonts.body().fontFamily),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        headerBackgroundColor: AppColors.accent,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle: AppFonts.display(size: 22, color: Colors.white),
        headerHelpStyle: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: Colors.white.withOpacity(0.85)),
        weekdayStyle: AppFonts.body(size: 12, weight: FontWeight.w700, color: AppColors.ink3),
        dayStyle: AppFonts.body(size: 13.5, color: AppColors.ink),
        dayForegroundColor: WidgetStateProperty.resolveWith(onDay),
        dayBackgroundColor: WidgetStateProperty.resolveWith(dayBg),
        dayOverlayColor: WidgetStateProperty.all(AppColors.accent.withOpacity(0.08)),
        todayForegroundColor: WidgetStateProperty.all(AppColors.accent),
        todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
        todayBorder: BorderSide(color: AppColors.accent, width: 1.2),
        rangePickerBackgroundColor: AppColors.card,
        rangePickerHeaderBackgroundColor: AppColors.accent,
        rangePickerHeaderForegroundColor: Colors.white,
        rangePickerHeaderHeadlineStyle: AppFonts.display(size: 20, color: Colors.white),
        rangePickerHeaderHelpStyle: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: Colors.white.withOpacity(0.85)),
        rangeSelectionBackgroundColor: AppColors.accentSoft,
        rangeSelectionOverlayColor: WidgetStateProperty.all(AppColors.accent.withOpacity(0.1)),
        dividerColor: AppColors.line,
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.ink2,
          textStyle: AppFonts.body(size: 13.5, weight: FontWeight.w600),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppFonts.body(size: 13.5, weight: FontWeight.w600),
        ),
      ),
    );
  }

  String _rangeLabel(DateTimeRange r) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String fmt(DateTime d) => '${months[d.month - 1]} ${d.day}, ${d.year}';
    return '${fmt(r.start)} – ${fmt(r.end)}';
  }

  String _periodLabel() {
    switch (_period) {
      case _Period.week:
        return 'this week';
      case _Period.month:
        return 'this month';
      case _Period.total:
        return 'total';
      case _Period.custom:
        return 'in range';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final orders = vm.orders;
    final periodOrders = orders.where(_matchesPeriod).toList();
    final query = _query.trim().toLowerCase();
    final filtered = periodOrders.where((o) => _matchesQuery(o, query)).toList();

    final statusTally = <String, int>{};
    for (final o in periodOrders) {
      final status = orderStatusOf(o) ?? 'Unknown';
      statusTally[status] = (statusTally[status] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Orders', style: AppFonts.display(size: 17)),
      ),
      body: SafeArea(
        child: orders.isEmpty
            ? _emptyState()
            : RefreshIndicator(
                color: AppColors.accent,
                onRefresh: vm.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  children: [
                    _summaryCard(periodOrders.length, statusTally),
                    const SizedBox(height: 14),
                    _periodFilterRow(),
                    const SizedBox(height: 12),
                    _searchField(),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            query.isNotEmpty
                                ? 'No orders match "${_searchCtrl.text}".'
                                : 'No orders ${_periodLabel()}.',
                            style: AppFonts.body(size: 13, color: AppColors.ink3),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _orderCard(o),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.shopping_bag_outlined, size: 28, color: AppColors.accent),
              ),
              const SizedBox(height: 16),
              Text('No orders yet', style: AppFonts.display(size: 17)),
              const SizedBox(height: 6),
              Text(
                'Orders placed by your customers will show up here.',
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 13, color: AppColors.ink3),
              ),
            ],
          ),
        ),
      );

  Widget _summaryCard(int total, Map<String, int> statusTally) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtN(total), style: AppFonts.display(size: 26)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(total == 1 ? 'order ${_periodLabel()}' : 'orders ${_periodLabel()}',
                      style: AppFonts.body(size: 12.5, color: AppColors.ink3)),
                ),
              ],
            ),
            if (statusTally.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: statusTally.entries.map((e) {
                  final color = orderStatusColor(e.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('${e.key} · ${e.value}',
                        style: AppFonts.body(size: 11.5, weight: FontWeight.w600, color: color)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );

  Widget _periodChip(String label, _Period period) {
    final selected = _period == period;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => period == _Period.custom ? _pickCustomRange() : setState(() => _period = period),
      labelStyle: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink2),
      backgroundColor: AppColors.card,
      selectedColor: AppColors.accent,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    );
  }

  Widget _periodFilterRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _periodChip('This week', _Period.week),
              _periodChip('This month', _Period.month),
              _periodChip('Total', _Period.total),
              _periodChip('Custom', _Period.custom),
            ],
          ),
          if (_period == _Period.custom && _customRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: _pickCustomRange,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.date_range_outlined, size: 14, color: AppColors.accent),
                    const SizedBox(width: 5),
                    Text(_rangeLabel(_customRange!),
                        style: AppFonts.body(size: 12, weight: FontWeight.w600, color: AppColors.accent)),
                  ],
                ),
              ),
            ),
        ],
      );

  Widget _searchField() => TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        style: AppFonts.body(size: 14, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search orders',
          hintStyle: AppFonts.body(size: 13.5, color: AppColors.ink3),
          prefixIcon: Icon(Icons.search, size: 19, color: AppColors.ink3),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent)),
        ),
      );

  Widget _orderCard(Map<String, dynamic> order) {
    final data = orderData(order);
    final title = orderTitle(order, data);
    final status = orderStatusOf(order);
    final created = parseDate(order['createdAt']);
    final color = orderStatusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showOrderDetail(context, order,
          onStatusChanged: context.read<DashboardViewModel>().updateOrderStatus,
          onSaved: () => context.read<DashboardViewModel>().refresh()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Text(
                    created != null ? fmtDateTime(created) : 'Order details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.body(size: 11.5, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                    child: Text(status, style: AppFonts.mono(size: 9.5, color: color)),
                  ),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
