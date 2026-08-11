import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../repositories/workspace_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/assistant_view_model.dart';
import '../widgets/app_logo.dart';
import 'account_view.dart';

class AssistantView extends StatelessWidget {
  const AssistantView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AssistantViewModel(ctx.read<WorkspaceRepository>()),
      child: const _AssistantBody(),
    );
  }
}

class _AssistantBody extends StatefulWidget {
  const _AssistantBody();

  @override
  State<_AssistantBody> createState() => _AssistantBodyState();
}

class _AssistantBodyState extends State<_AssistantBody> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(AssistantViewModel vm, [String? text]) async {
    final content = (text ?? _inputCtrl.text).trim();
    if (content.isEmpty) return;
    if (!vm.keyReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an AI key in Account to start'), behavior: SnackBarBehavior.floating),
      );
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountView()));
      return;
    }
    _inputCtrl.clear();
    _scrollToBottom();
    await vm.send(content);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssistantViewModel>();
    final suggests = vm.suggestions;

    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(color: AppColors.card, border: Border(bottom: BorderSide(color: AppColors.line))),
              child: Row(
                children: [
                  const AppLogoMark(size: 38),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vm.brand, style: AppFonts.body(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
                        Text(vm.sending ? 'Thinking…' : 'Ready', style: AppFonts.body(size: 12, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: vm.clearChat,
                    icon: Icon(Icons.refresh, color: AppColors.ink2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                children: [
                  if (vm.chatMessages.isEmpty)
                    _bubble(
                      context,
                      "Hi — I'm the AI assistant for **${vm.business?.name ?? 'your business'}**. I can answer questions and help your customers, drawing on the documents you've added under Docs. This is your preview — what your customers would experience.",
                      isMe: false,
                    )
                  else
                    ...vm.chatMessages.map((m) => _bubble(context, m['content'] ?? '', isMe: m['role'] == 'user')),
                  if (vm.sending) _typing(),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: suggests.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => _send(vm, suggests[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.paper2, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.line2)),
                    child: Text(suggests[i], style: AppFonts.body(size: 12.5, color: AppColors.ink)),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.line))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 5,
                      style: AppFonts.body(size: 14.5, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: 'Ask anything…',
                        hintStyle: AppFonts.body(size: 14.5, color: AppColors.ink3),
                        filled: true,
                        fillColor: AppColors.paper2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(vm),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(23),
                    onTap: vm.sending ? null : () => _send(vm),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: vm.sending ? AppColors.ink3 : AppColors.accent, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, String text, {required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.line),
        ),
        child: isMe
            ? Text(text, style: AppFonts.body(size: 14, color: Colors.white))
            : MarkdownBody(
                data: text,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: AppFonts.body(size: 14, color: AppColors.ink),
                  strong: AppFonts.body(size: 14, weight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
      ),
    );
  }

  Widget _typing() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: const SizedBox(width: 20, height: 12, child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))),
      ),
    );
  }
}
