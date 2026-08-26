import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/job_type_schema.dart';
import '../models/plan.dart';
import '../repositories/workspace_repository.dart';
import '../services/api_client.dart';
import '../services/job_instance_update_service.dart';
import '../services/job_type_schema_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../widgets/business_icons.dart';
import '../widgets/job_type_fields_form.dart' show getMaskedValue;
import '../widgets/status_changer.dart';
import 'home_shell_view.dart';
import 'job_instance_edit_view.dart';

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

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDateTime(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  final minute = t.minute.toString().padLeft(2, '0');
  return '${_kMonths[t.month - 1]} ${t.day}, ${t.year} · $hour12:$minute $ampm';
}

String initialsOf(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  final a = p.isNotEmpty && p[0].isNotEmpty ? p[0][0] : '';
  final b = p.length > 1 && p[1].isNotEmpty ? p[1][0] : '';
  return (a + b).toUpperCase();
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => DashboardViewModel(
          ctx.read<WorkspaceRepository>(), ctx.read<SessionStorage>(), ctx.read<ApiClient>()),
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
    final data = vm.businessData;
    final heroName = firstNonEmpty(data, const ['Business Name', 'businessName', 'Company Name', 'Name']) ?? '';
    final heroOwner = firstNonEmpty(data, const ['Owner Name', 'ownerName', 'Contact Name', 'Full Name']) ??
        [firstNonEmpty(data, const ['First Name']), firstNonEmpty(data, const ['Last Name'])]
            .whereType<String>()
            .join(' ');
    final heroCategory = firstNonEmpty(data, const ['Business Category', 'businessCategory'])?.split('(').first.trim();
    final heroHours = firstNonEmpty(data, const ['Availabilty Times', 'Availability Times'])?.split('(').first.trim();
    final plan = planById(biz.planId);
    final bks = vm.bookings;
    final now = DateTime.now();
    final bksWeek = bks.where((b) {
      final created = recordReferenceDate(b);
      return created != null && now.difference(created).inDays < 7;
    }).length;
    final bksMonth = bks.where((b) {
      final created = recordReferenceDate(b);
      return created != null && created.year == now.year && created.month == now.month;
    }).length;
    final orders = vm.orders;
    final ordersWeek = orders.where((o) {
      final created = recordReferenceDate(o);
      return created != null && now.difference(created).inDays < 7;
    }).length;
    final ordersMonth = orders.where((o) {
      final created = recordReferenceDate(o);
      return created != null && created.year == now.year && created.month == now.month;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: vm.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _hero(heroName, heroOwner, greet, heroCategory, heroHours, plan),
              const SizedBox(height: 14),
              _kpiGrid(context, bks.length, vm.ordersCount),
              _sectionHeader('Bookings', 'Calendar →', () => _goTab(context, 1)),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _stat(fmtN(bks.length), 'total'),
                        _stat(fmtN(bksWeek), 'this week'),
                        _stat(fmtN(bksMonth), 'this month'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (bks.isEmpty)
                      _empty('No bookings yet.')
                    else
                      ...bks.take(5).map((b) => bookingRow(context, b)),
                  ],
                ),
              ),
              _sectionHeader('Orders', 'View all →', () => _goTab(context, 2)),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _stat(fmtN(orders.length), 'total'),
                        _stat(fmtN(ordersWeek), 'this week'),
                        _stat(fmtN(ordersMonth), 'this month'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (orders.isEmpty)
                      _empty('No orders yet.')
                    else
                      ...orders.take(5).map((o) => orderRow(context, o)),
                  ],
                ),
              ),
              _sectionHeader('Files uploaded', 'Manage →', () => _goTab(context, 4)),
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
                        onPressed: () => _goTab(context, 4),
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

  Widget _hero(String name, String owner, String greet, String? category, String? hours, Plan plan) {
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
          if (category != null || hours != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (category != null) _heroTag(Icons.category_outlined, category),
                if (hours != null) _heroTag(Icons.access_time_outlined, hours),
              ],
            ),
          ],
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

  Widget _kpiGrid(BuildContext context, int bookings, int ordersCount) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _kpi(Icons.calendar_month_outlined, fmtN(bookings), 'Bookings', AppColors.accent, AppColors.accentSoft, () => _goTab(context, 1)),
        _kpi(Icons.shopping_bag_outlined, fmtN(ordersCount), 'Orders', const Color(0xFF4F46E5), const Color(0x194F46E5), () => _goTab(context, 2)),
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

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, textAlign: TextAlign.center, style: AppFonts.body(size: 12.5, color: AppColors.ink3)),
      );

}

Widget _detailRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.body(size: 11, color: AppColors.ink3)),
                const SizedBox(height: 2),
                Text(value, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );

String? firstNonEmpty(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return null;
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

Map<String, dynamic> orderData(Map<String, dynamic> order) =>
    order['data'] is Map ? Map<String, dynamic>.from(order['data'] as Map) : <String, dynamic>{};

DateTime? recordReferenceDate(Map<String, dynamic> record) {
  final dateRaw = firstNonEmpty(orderData(record), const ['Booking Date', 'Appointment Date', 'Scheduled Date', 'Order Date', 'Date']);
  if (dateRaw != null) {
    final parsed = DateTime.tryParse(dateRaw)?.toLocal();
    if (parsed != null) return parsed;
  }
  return parseDate(record['dateCreated']) ?? parseDate(record['createdAt']);
}

String orderTitle(Map<String, dynamic> order, Map<String, dynamic> data) =>
    firstNonEmpty(data, const ['Customer Name', 'Name', 'Title', 'Product Name', 'Product', 'Item', 'Order Name']) ??
    'Order ${_shortId(order)}';

String _shortId(Map<String, dynamic> order, {bool full = false}) {
  final id = (order['id'] ?? order['_id'])?.toString() ?? '';
  if (id.isEmpty) return '—';
  if (full || id.length <= 8) return id;
  return id.substring(id.length - 8);
}

// .toLocal() matters wherever a caller reads .year/.month/.day off the
// result (calendar day-bucketing, "this week"/"this month" grouping) — a
// UTC timestamp near local midnight would otherwise land on the wrong day.
// .difference()-based comparisons are timezone-invariant either way.
DateTime? parseDate(dynamic value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

String stripHtml(String input) {
  if (!input.contains('<')) return input;
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

String? orderStatusOf(Map<String, dynamic> order) {
  final jobLevelStatus = order[AppConstants.fieldCurrentJobStatus];
  if (jobLevelStatus is String && jobLevelStatus.trim().isNotEmpty) {
    return jobLevelStatus.trim();
  }

  final data = orderData(order);
  for (final entry in data.entries) {
    if (entry.key.toLowerCase() == 'status' &&
        entry.value is String &&
        (entry.value as String).trim().isNotEmpty) {
      return (entry.value as String).trim();
    }
  }
  return null;
}

Color orderStatusColor(String? status) {
  final s = (status ?? '').toLowerCase();
  if (s.contains('deliver') || s.contains('complet') || s.contains('paid')) return AppColors.ok;
  if (s.contains('transit') || s.contains('process') || s.contains('progress')) return AppColors.amber;
  if (s.contains('cancel') || s.contains('fail') || s.contains('reject')) return AppColors.danger;
  if (s.contains('placed') || s.contains('pend')) return AppColors.ink3;
  return AppColors.accent;
}

Widget closeEditRow(BuildContext ctx, VoidCallback onEdit) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.line2),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Close', style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: onEdit,
          child: Text('Edit', style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    ],
  );
}

String _humanizeKey(String key) {
  if (key.contains(' ')) return key;
  final spaced = key.replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (m) => ' ');
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

final _trailingIdPattern = RegExp(r'\s*\([^()]*\)\s*$');

String stripTrailingId(String value) => value
    .split(',')
    .map((part) => part.replaceAll(_trailingIdPattern, '').trim())
    .join(', ');

List<MapEntry<String, dynamic>> prioritizeDateTimeFields(Iterable<MapEntry<String, dynamic>> fields) {
  final priority = <MapEntry<String, dynamic>>[];
  final rest = <MapEntry<String, dynamic>>[];
  for (final e in fields) {
    final k = e.key.trim().toLowerCase();
    (k.endsWith('date') || k.endsWith('time') ? priority : rest).add(e);
  }
  return [...priority, ...rest];
}

String formatDetailValue(String raw) {
  final value = stripTrailingId(stripHtml(raw));
  if (RegExp(r'^\d+$').hasMatch(value)) return value;
  final dt = DateTime.tryParse(value);
  if (dt == null) return value;
  final local = dt.toLocal();
  final hasTime = local.hour != 0 || local.minute != 0;
  return hasTime ? fmtDateTimeDMY(dt) : fmtDateDMY(dt);
}

bool isTimeOnlyKey(String key) {
  final k = key.trim().toLowerCase();
  return (k == 'time' || k.endsWith('time')) && !k.contains('date');
}

String formatTimeOnlyValue(String raw) {
  final value = stripTrailingId(stripHtml(raw));
  final dt = DateTime.tryParse(value);
  return dt == null ? value : fmtTimeOnly(dt);
}

Widget maskedDetailFields({
  required Future<JobTypeSchema?> schemaFuture,
  required List<MapEntry<String, dynamic>> fields,
  required Widget Function(String key, String rawValue, String display) rowBuilder,
}) {
  return FutureBuilder<JobTypeSchema?>(
    future: schemaFuture,
    builder: (context, snapshot) {
      final schema = snapshot.data;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.map((e) {
          final raw = e.value.toString();
          final field = schema?.fieldNamed(e.key);
          final display = field != null && field.mask.isNotEmpty
              ? getMaskedValue(raw, field.mask).formattedValue
              : isTimeOnlyKey(e.key)
                  ? formatTimeOnlyValue(raw)
                  : formatDetailValue(raw);
          return rowBuilder(e.key, raw, display);
        }).toList(),
      );
    },
  );
}

Widget orderRow(BuildContext context, Map<String, dynamic> order) {
  final data = orderData(order);
  final title = orderTitle(order, data);
  final rawSubtitle = firstNonEmpty(data, const ['Item Name', 'Item', 'Product Name', 'Product', 'Service', 'Status']);
  final subtitle = rawSubtitle == null ? 'Tap for details' : stripHtml(rawSubtitle);
  final created = parseDate(order['createdAt']);
  final status = orderStatusOf(order);
  final statusColor = orderStatusColor(status);
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => showOrderDetail(context, order,
        onStatusChanged: context.read<DashboardViewModel>().updateOrderStatus,
        onSaved: () => context.read<DashboardViewModel>().refresh()),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
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
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                  child: Text(status, style: AppFonts.mono(size: 9.5, color: statusColor)),
                ),
              if (created != null) ...[
                const SizedBox(height: 4),
                Text(timeAgo(created), style: AppFonts.body(size: 10.5, color: AppColors.ink3)),
              ],
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
        ],
      ),
    ),
  );
}

void showOrderDetail(BuildContext context, Map<String, dynamic> order,
    {required void Function(Map<String, dynamic> order, String status) onStatusChanged,
    required VoidCallback onSaved}) {
  final title = orderTitle(order, orderData(order));
  final created = parseDate(order['createdAt']);
  final instanceId = (order['id'] ?? order['_id'])?.toString() ?? '';
  final schemaFuture = fetchJobTypeSchema(context.read<ApiClient>(), AppConstants.jobTypeOrders);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final data = orderData(order);
        final fields = prioritizeDateTimeFields(data.entries
            .where((e) => e.key.toLowerCase() != 'status')
            .where((e) => e.value is String || e.value is num || e.value is bool)
            .where((e) => e.value.toString().trim().isNotEmpty))
            .toList();

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title, style: AppFonts.display(size: 17))),
                      StatusChanger(
                        instanceId: instanceId,
                        currentStatus: orderStatusOf(order),
                        statusColor: orderStatusColor,
                        onChanged: (s) {
                          onStatusChanged(order, s);
                          setSheetState(() {});
                        },
                        onNeedsForm: (option) => Navigator.of(context).push<bool>(MaterialPageRoute(
                              builder: (_) => JobInstanceEditView(
                                title: 'Add ${option.subJobTypeName}',
                                jobTypeName: option.subJobTypeName!,
                                instanceId: '',
                                initialData: const {},
                                onSave: (id, values, jobTypeId) => saveJobInstance(
                                    context.read<ApiClient>(), instanceId: id, jobTypeId: jobTypeId, data: values),
                              ),
                            )).then((completed) {
                              if (completed == true) onSaved();
                              return completed ?? false;
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (created != null) _detailRow(Icons.event_outlined, 'Created', fmtDateTime(created)),
                  if (fields.isEmpty)
                    _detailRow(Icons.info_outline, 'Details', 'No additional details available.')
                  else
                    maskedDetailFields(
                      schemaFuture: schemaFuture,
                      fields: fields,
                      rowBuilder: (key, raw, display) => _detailRow(Icons.info_outline, _humanizeKey(key), display),
                    ),
                  _detailRow(Icons.tag, 'Order ID', _shortId(order, full: true)),
                  const SizedBox(height: 4),
                  closeEditRow(ctx, () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => JobInstanceEditView(
                        title: 'Edit Order',
                        jobTypeName: AppConstants.jobTypeOrders,
                        instanceId: instanceId,
                        initialData: data,
                        onSave: (id, values, jobTypeId) => saveJobInstance(
                            context.read<ApiClient>(), instanceId: id, jobTypeId: jobTypeId, data: values),
                      ),
                    )).then((saved) {
                      if (saved == true) onSaved();
                    });
                  }),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget bookingRow(BuildContext context, Map<String, dynamic> booking) {
  final data = orderData(booking);
  final title = firstNonEmpty(data, const ['Customer Name', 'Name', 'Full Name']) ?? 'Booking ${_shortId(booking)}';
  final rawSubtitle = firstNonEmpty(data, const ['Service Name', 'Service', 'Item Name', 'Item']);
  final subtitle = rawSubtitle == null ? 'Tap for details' : stripHtml(rawSubtitle);
  final created = parseDate(booking['createdAt']);
  final status = orderStatusOf(booking);
  final color = orderStatusColor(status);
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => showBookingDetail(context, booking,
        onStatusChanged: context.read<DashboardViewModel>().updateOrderStatus,
        onSaved: () => context.read<DashboardViewModel>().refresh()),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initialsOf(title), style: AppFonts.body(size: 11.5, weight: FontWeight.w700, color: AppColors.accent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 13.5, weight: FontWeight.w600, color: AppColors.ink)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                  child: Text(status, style: AppFonts.mono(size: 9.5, color: color)),
                ),
              if (created != null) ...[
                const SizedBox(height: 3),
                Text(timeAgo(created), style: AppFonts.body(size: 10.5, color: AppColors.ink3)),
              ],
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: AppColors.ink3),
        ],
      ),
    ),
  );
}

void showBookingDetail(BuildContext context, Map<String, dynamic> booking,
    {required void Function(Map<String, dynamic> booking, String status) onStatusChanged,
    required VoidCallback onSaved}) {
  final data = orderData(booking);
  final title = firstNonEmpty(data, const ['Customer Name', 'Name', 'Full Name']) ?? 'Booking ${_shortId(booking)}';
  final created = parseDate(booking['createdAt']);
  final instanceId = (booking['id'] ?? booking['_id'])?.toString() ?? '';
  final schemaFuture = fetchJobTypeSchema(context.read<ApiClient>(), AppConstants.jobTypeBookings);
  final fields = prioritizeDateTimeFields(data.entries
      .where((e) => e.key.toLowerCase() != 'status')
      .where((e) => e.value is String || e.value is num || e.value is bool)
      .where((e) => e.value.toString().trim().isNotEmpty))
      .toList();

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(100)),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initialsOf(title), style: AppFonts.body(size: 14, weight: FontWeight.w700, color: AppColors.accent)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppFonts.display(size: 17)),
                        const SizedBox(height: 4),
                        StatusChanger(
                          instanceId: instanceId,
                          currentStatus: orderStatusOf(booking),
                          statusColor: orderStatusColor,
                          onChanged: (s) => onStatusChanged(booking, s),
                          onNeedsForm: (option) => Navigator.of(context).push<bool>(MaterialPageRoute(
                                builder: (_) => JobInstanceEditView(
                                  title: 'Add ${option.subJobTypeName}',
                                  jobTypeName: option.subJobTypeName!,
                                  instanceId: '',
                                  initialData: const {},
                                  onSave: (id, values, jobTypeId) => saveJobInstance(
                                      context.read<ApiClient>(), instanceId: id, jobTypeId: jobTypeId, data: values),
                                ),
                              )).then((completed) {
                                if (completed == true) onSaved();
                                return completed ?? false;
                              }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (created != null) _detailRow(Icons.event_outlined, 'Created', fmtDateTime(created)),
              if (fields.isEmpty)
                _detailRow(Icons.info_outline, 'Details', 'No additional details available.')
              else
                maskedDetailFields(
                  schemaFuture: schemaFuture,
                  fields: fields,
                  rowBuilder: (key, raw, display) => _detailRow(Icons.info_outline, _humanizeKey(key), display),
                ),
              _detailRow(Icons.tag, 'Booking ID', _shortId(booking, full: true)),
              const SizedBox(height: 4),
              closeEditRow(ctx, () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => JobInstanceEditView(
                    title: 'Edit Booking',
                    jobTypeName: AppConstants.jobTypeBookings,
                    instanceId: instanceId,
                    initialData: data,
                    onSave: (id, values, jobTypeId) => saveJobInstance(context.read<ApiClient>(),
                        instanceId: id, jobTypeId: jobTypeId, data: values),
                  ),
                )).then((saved) {
                  if (saved == true) onSaved();
                });
              }),
            ],
          ),
        ),
      ),
    ),
  );
}
