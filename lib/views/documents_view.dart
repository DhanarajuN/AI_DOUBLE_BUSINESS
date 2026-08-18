import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doc_source.dart';
import '../repositories/workspace_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/knowledge_view_model.dart';
import '../widgets/business_icons.dart';

class DocumentsView extends StatelessWidget {
  const DocumentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => KnowledgeViewModel(ctx.read<WorkspaceRepository>()),
      child: const _DocumentsBody(),
    );
  }
}

class _DocumentsBody extends StatefulWidget {
  const _DocumentsBody();

  @override
  State<_DocumentsBody> createState() => _DocumentsBodyState();
}

class _DocumentsBodyState extends State<_DocumentsBody> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _addText(KnowledgeViewModel vm) async {
    final error = await vm.addText(_titleCtrl.text, _textCtrl.text);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), behavior: SnackBarBehavior.floating));
      return;
    }
    _titleCtrl.clear();
    _textCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source added'), behavior: SnackBarBehavior.floating));
  }

  Future<void> _pickFile(KnowledgeViewModel vm) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'csv', 'json', 'log'],
    );
    if (result == null || !mounted) return;
    final files = [
      for (final f in result.files)
        if (f.bytes != null) (f.name, f.bytes!, f.size),
    ];
    final warnings = await vm.addPickedFiles(files);
    if (!mounted) return;
    for (final w in warnings) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(w), behavior: SnackBarBehavior.floating));
    }
    if (warnings.length < files.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File added'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KnowledgeViewModel>();
    final totalChars = vm.docs.fold<int>(0, (a, d) => a + d.text.length);

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Your documents', style: AppFonts.display(size: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Text(
              'What you add here becomes the context the assistant answers from. It stays on this device; only the text you send is passed to your AI provider.',
              style: AppFonts.body(size: 13, color: AppColors.ink2).copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _stat('${vm.docs.length}', 'Sources'),
                _stat('${(totalChars / 1000).toStringAsFixed(1)}k', 'Characters'),
                _stat(vm.keyReady ? 'On' : 'Off', 'AI connected'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _srcTab('Paste text', vm.mode == KnowledgeSourceMode.paste, () => vm.setMode(KnowledgeSourceMode.paste))),
                  Expanded(child: _srcTab('Upload file', vm.mode == KnowledgeSourceMode.upload, () => vm.setMode(KnowledgeSourceMode.upload))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (vm.mode == KnowledgeSourceMode.paste) _pasteArea(vm) else _uploadArea(vm),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sources', style: AppFonts.display(size: 17)),
                if (vm.docs.isNotEmpty)
                  GestureDetector(
                    onTap: vm.clearDocs,
                    child: Text('Clear all', style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: AppColors.accent)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (vm.docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
                child: Text(
                  'No sources yet. Add a document and the assistant will answer from it — with the source named.',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(size: 13, color: AppColors.ink3),
                ),
              )
            else
              ...vm.docs.map((d) => _docRow(vm, d)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppFonts.display(size: 20)),
              Text(label, style: AppFonts.body(size: 11, color: AppColors.ink3)),
            ],
          ),
        ),
      );

  Widget _srcTab(String label, bool on, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? AppColors.card : null, borderRadius: BorderRadius.circular(9)),
          child: Text(label, style: AppFonts.body(size: 12.5, weight: FontWeight.w600, color: on ? AppColors.ink : AppColors.ink2)),
        ),
      );

  Widget _pasteArea(KnowledgeViewModel vm) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: AppColors.line2));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleCtrl,
          style: AppFonts.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Title (e.g. Price list 2026)',
            hintStyle: AppFonts.body(size: 13.5, color: AppColors.ink3),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _textCtrl,
          maxLines: 6,
          style: AppFonts.body(size: 13.5, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: "Paste a price list, FAQ, policy clause — anything you'd want answered from.",
            hintStyle: AppFonts.body(size: 13, color: AppColors.ink3),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.all(13),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _addText(vm),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Add source', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _uploadArea(KnowledgeViewModel vm) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: vm.picking ? null : () => _pickFile(vm),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line2, width: 1.4, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: vm.picking
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Icon(Icons.upload_outlined, color: AppColors.accent, size: 22),
            ),
            const SizedBox(height: 10),
            Text('Tap to browse for a file', style: AppFonts.body(size: 14, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text('txt · md · csv · json · log — text is read on-device', style: AppFonts.mono(size: 10.5, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }

  Widget _docRow(KnowledgeViewModel vm, DocSource d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(businessIcon(d.isFile ? 'file' : 'doc'), size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                Text(d.meta, style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => vm.removeDoc(d.id),
            icon: Icon(Icons.delete_outline, color: AppColors.ink3, size: 20),
          ),
        ],
      ),
    );
  }
}
