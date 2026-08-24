import 'package:flutter/material.dart';
import '../models/job_type_schema.dart';
import '../theme/app_theme.dart';

Future<void> showSearchableOptionsPicker(
  BuildContext context, {
  required String title,
  required List<JobTypeFieldOption> options,
  required bool multiselect,
  required Set<String> selectedValues,
  required void Function(JobTypeFieldOption option) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _OptionsPickerSheet(
      title: title,
      options: options,
      multiselect: multiselect,
      selectedValues: selectedValues,
      onSelect: onSelect,
    ),
  );
}

class _OptionsPickerSheet extends StatefulWidget {
  final String title;
  final List<JobTypeFieldOption> options;
  final bool multiselect;
  final Set<String> selectedValues;
  final void Function(JobTypeFieldOption option) onSelect;

  const _OptionsPickerSheet({
    required this.title,
    required this.options,
    required this.multiselect,
    required this.selectedValues,
    required this.onSelect,
  });

  @override
  State<_OptionsPickerSheet> createState() => _OptionsPickerSheetState();
}

class _OptionsPickerSheetState extends State<_OptionsPickerSheet> {
  String _query = '';
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.selectedValues);
  }

  void _handleTap(JobTypeFieldOption option) {
    widget.onSelect(option);
    if (!widget.multiselect) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      if (!_selected.remove(option.submissionValue)) _selected.add(option.submissionValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.options
        : widget.options.where((o) => o.label.toLowerCase().contains(_query.toLowerCase())).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  Text(widget.title, style: AppFonts.display(size: 17)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: AppFonts.body(size: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      hintStyle: AppFonts.body(size: 14, color: AppColors.ink3),
                      prefixIcon: Icon(Icons.search, size: 19, color: AppColors.ink3),
                      filled: true,
                      fillColor: AppColors.paper2,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2)),
                      enabledBorder:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2)),
                      focusedBorder:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.accent)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No matches.', style: AppFonts.body(size: 13, color: AppColors.ink3)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final option = filtered[i];
                        final selected = _selected.contains(option.submissionValue);
                        return ListTile(
                          title: Text(option.label, style: AppFonts.body(size: 14, color: AppColors.ink)),
                          trailing: selected ? Icon(Icons.check, color: AppColors.accent) : null,
                          onTap: () => _handleTap(option),
                        );
                      },
                    ),
            ),
            if (widget.multiselect)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Done', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
