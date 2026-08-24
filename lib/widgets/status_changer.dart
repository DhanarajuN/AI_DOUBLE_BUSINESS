import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_status_option.dart';
import '../services/api_client.dart';
import '../services/app_logger.dart';
import '../services/friendly_error.dart';
import '../services/job_status_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';

class StatusChanger extends StatefulWidget {
  final String instanceId;
  final String? currentStatus;
  final Color Function(String? status) statusColor;
  final ValueChanged<String>? onChanged;

  const StatusChanger({
    super.key,
    required this.instanceId,
    required this.currentStatus,
    required this.statusColor,
    this.onChanged,
  });

  @override
  State<StatusChanger> createState() => _StatusChangerState();
}

class _StatusChangerState extends State<StatusChanger> {
  List<JobStatusOption> _options = const [];
  bool _loadingOptions = true;
  bool _submitting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
    _loadNextStatuses();
  }

  Future<void> _loadNextStatuses() async {
    if (widget.instanceId.isEmpty) {
      setState(() => _loadingOptions = false);
      return;
    }
    try {
      final apiClient = context.read<ApiClient>();
      final roleName = await context.read<SessionStorage>().readRoleName();
      AppLogger.i('StatusChanger', 'Checking role "${roleName ?? 'none'}" against next statuses for ${widget.instanceId}');
      final options = await fetchNextJobStatuses(apiClient, widget.instanceId);
      final allowed = options.where((o) => o.allowsRole(roleName)).toList();
      AppLogger.i('StatusChanger',
          'Role "${roleName ?? 'none'}" allowed ${allowed.length}/${options.length} status option(s) for ${widget.instanceId}');
      if (!mounted) return;
      setState(() {
        _options = allowed;
        _loadingOptions = false;
      });
    } catch (e, st) {
      AppLogger.e('StatusChanger', 'loadNextStatuses(${widget.instanceId}) failed', e, st);
      if (!mounted) return;
      setState(() => _loadingOptions = false);
    }
  }

  Future<void> _changeTo(String newStatus) async {
    setState(() => _submitting = true);
    try {
      await updateJobStatus(context.read<ApiClient>(), instanceId: widget.instanceId, status: newStatus);
      if (!mounted) return;
      setState(() {
        _status = newStatus;
        _submitting = false;
      });
      widget.onChanged?.call(newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus'), behavior: SnackBarBehavior.floating),
      );
    } catch (e, st) {
      final message = logFriendlyError('StatusChanger', e, st);
      if (!mounted) return;
      setState(() => _submitting = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Could not update status', style: AppFonts.display(size: 16)),
          content: Text(message, style: AppFonts.body(size: 13.5, color: AppColors.ink2)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.accent)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.statusColor(_status);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
      child: Text(_status ?? 'Unknown', style: AppFonts.mono(size: 10, color: color)),
    );

    if (_submitting) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const SizedBox(width: 8),
          SizedBox(
              width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.ink3)),
          const SizedBox(width: 6),
          Text('Updating…', style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
        ],
      );
    }

    if (_loadingOptions || _options.isEmpty) return pill;

    return PopupMenuButton<String>(
      onSelected: _changeTo,
      itemBuilder: (ctx) => _options
          .map((o) => PopupMenuItem<String>(value: o.secondaryStatus, child: Text(o.secondaryStatus)))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 18, color: AppColors.ink3),
        ],
      ),
    );
  }
}
