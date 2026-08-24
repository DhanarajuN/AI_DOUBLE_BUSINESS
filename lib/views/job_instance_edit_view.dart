import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_type_schema.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';
import '../services/attachment_upload_service.dart';
import '../theme/app_theme.dart';
import '../viewmodels/job_instance_edit_view_model.dart';
import '../widgets/job_type_fields_form.dart';

class JobInstanceEditView extends StatelessWidget {
  final String title;
  final String jobTypeName;
  final String instanceId;
  final Map<String, dynamic> initialData;
  final Future<void> Function(String instanceId, Map<String, dynamic> data) onSave;

  const JobInstanceEditView({
    super.key,
    required this.title,
    required this.jobTypeName,
    required this.instanceId,
    required this.initialData,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => JobInstanceEditViewModel(
        ctx.read<ApiClient>(),
        jobTypeName: jobTypeName,
        instanceId: instanceId,
        initialData: initialData,
        currentUserEmail: ctx.read<AuthRepository>().currentUser?.username,
      ),
      child: _JobInstanceEditBody(title: title, onSave: onSave),
    );
  }
}

class _JobInstanceEditBody extends StatelessWidget {
  final String title;
  final Future<void> Function(String instanceId, Map<String, dynamic> data) onSave;

  const _JobInstanceEditBody({required this.title, required this.onSave});

  Future<void> _save(BuildContext context, JobInstanceEditViewModel vm) async {
    final error = await vm.save(onSave);
    if (!context.mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<JobInstanceEditViewModel>();

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(child: _body(context, vm)),
    );
  }

  Widget _body(BuildContext context, JobInstanceEditViewModel vm) {
    if (vm.loadingSchema) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.schemaFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load this form.", style: AppFonts.body(size: 13.5, color: AppColors.ink2)),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: vm.retryLoadSchema,
                child: Text('Retry', style: AppFonts.body(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
              ),
            ],
          ),
        ),
      );
    }

    final groups = <String>[];
    for (final f in vm.editableFields) {
      if (f.groupName.isEmpty || groups.contains(f.groupName)) continue;
      groups.add(f.groupName);
    }
    final ungrouped = vm.editableFields.where((f) => f.groupName.isEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final group in groups) ...[
          Text(group, style: AppFonts.display(size: 15, color: AppColors.accent)),
          const SizedBox(height: 12),
          ..._groupBody(context, vm, group),
          const SizedBox(height: 8),
        ],
        if (ungrouped.isNotEmpty) _fieldsForm(context, vm, ungrouped),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            onPressed: vm.saving ? null : () => _save(context, vm),
            child: Text(vm.saving ? 'Saving…' : 'Save changes',
                style: AppFonts.body(size: 14.5, weight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _fieldsForm(BuildContext context, JobInstanceEditViewModel vm, List<JobTypeField> fields) {
    return JobTypeFieldsForm(
      fields: fields,
      valueOf: vm.valueOf,
      optionsFor: vm.optionsForField,
      onTextChanged: vm.setTextValue,
      onPickSingle: vm.pickSingleValue,
      onToggleMulti: vm.toggleMultiValue,
      onUploadFile: (fileName, bytes) => uploadAttachment(
        context.read<ApiClient>(),
        fileName: fileName,
        bytes: bytes,
        parentJobTypeId: vm.schema?.jobTypeId ?? '',
      ),
      onAttachmentsAdded: (field, files) => vm.addAttachments(field.name, files),
      onAttachmentRemoved: (field, file) => vm.removeAttachment(field.name, file),
    );
  }

  // Fields whose group is bound to a specific repetition index (an "Add
  // More" group) — every value read/write is redirected through the
  // ViewModel's indexed accessors instead of its flat ones, so the same
  // JobTypeFieldsForm widget renders each section independently without
  // needing to know sections exist at all.
  Widget _fieldsFormAt(BuildContext context, JobInstanceEditViewModel vm, List<JobTypeField> fields, int index) {
    return JobTypeFieldsForm(
      fields: fields,
      valueOf: (name) => vm.valueAt(name, index),
      optionsFor: (field) => vm.optionsForFieldAt(field, index),
      onTextChanged: (name, value) => vm.setTextValueAt(name, index, value),
      onPickSingle: (field, option) => vm.pickSingleValueAt(field, index, option),
      onToggleMulti: (field, option) => vm.toggleMultiValueAt(field, index, option),
      onUploadFile: (fileName, bytes) => uploadAttachment(
        context.read<ApiClient>(),
        fileName: fileName,
        bytes: bytes,
        parentJobTypeId: vm.schema?.jobTypeId ?? '',
      ),
      onAttachmentsAdded: (field, files) => vm.addAttachments(field.name, files),
      onAttachmentRemoved: (field, file) => vm.removeAttachment(field.name, file),
    );
  }

  List<Widget> _groupBody(BuildContext context, JobInstanceEditViewModel vm, String group) {
    final fields = vm.fieldsForGroup(group);
    if (!fields.any((f) => f.enableAddMore)) {
      return [_fieldsForm(context, vm, fields)];
    }

    final count = vm.sectionCountFor(group);
    return [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (count > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$group ${i + 1}', style: AppFonts.body(size: 12, weight: FontWeight.w700, color: AppColors.ink3)),
                      InkWell(
                        onTap: () => vm.removeSection(group, i),
                        child: const Icon(Icons.close, size: 16, color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              _fieldsFormAt(context, vm, fields, i),
            ],
          ),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => vm.addSection(group),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.line2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        icon: Icon(Icons.add, size: 16, color: AppColors.accent),
        label: Text('Add another $group', style: AppFonts.body(size: 13, weight: FontWeight.w600, color: AppColors.accent)),
      ),
    ];
  }
}
