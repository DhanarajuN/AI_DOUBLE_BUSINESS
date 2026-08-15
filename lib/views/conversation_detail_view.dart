import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../models/gosure_conversation.dart';
import '../models/gosure_message.dart';
import '../repositories/business_conversations_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/conversation_detail_view_model.dart';

class ConversationDetailView extends StatelessWidget {
  final GosureConversation conversation;
  final String businessId;
  const ConversationDetailView(
      {super.key, required this.conversation, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ConversationDetailViewModel(
          ctx.read<BusinessConversationsRepository>(), businessId),
      child: _ConversationDetailBody(conversation: conversation),
    );
  }
}

class _ConversationDetailBody extends StatefulWidget {
  final GosureConversation conversation;
  const _ConversationDetailBody({required this.conversation});

  @override
  State<_ConversationDetailBody> createState() =>
      _ConversationDetailBodyState();
}

class _ConversationDetailBodyState extends State<_ConversationDetailBody> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _lastMessageCount = 0;
  // Captured once, up front — calling context.read() inside dispose() is unsafe
  // because a fast back-navigation can deactivate this widget before dispose()
  // runs, and looking up a Provider ancestor on a deactivated widget throws
  // ("Looking up a deactivated widget's ancestor is unsafe"), repeatedly, badly
  // enough to corrupt the widget tree and leave the app showing a blank screen.
  late final ConversationDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ConversationDetailViewModel>();
    // open() ends up calling notifyListeners() on BusinessConversationsRepository — the
    // SAME repository the list screen underneath (kept alive by IndexedStack) is still
    // watching. Calling that synchronously from initState() notifies an ANCESTOR widget
    // while this route's own widget tree is still mid-build/mount, which Flutter forbids
    // ("setState() or markNeedsBuild() called during build") and was corrupting the tree
    // badly enough to show stale/wrong conversations or a blank red error screen.
    // Deferring to the next frame lets this build finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vm.open(widget.conversation);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _vm.close();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(ConversationDetailViewModel vm) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    try {
      await vm.send(text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not send: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _toggleAgentChatMode(
      ConversationDetailViewModel vm, bool value) async {
    try {
      await vm.toggleAgentChatMode(value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not update agent mode: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConversationDetailViewModel>();
    final convo = vm.conversation ?? widget.conversation;
    final agentOn = vm.agentChatMode;

    // Only auto-scroll when a message was actually added, not on every rebuild (e.g. toggling
    // the switch) — otherwise it'd fight a business user scrolling up to read history.
    if (vm.messages.length != _lastMessageCount) {
      _lastMessageCount = vm.messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AppColors.paper2,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
              decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border(bottom: BorderSide(color: AppColors.line))),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.ink2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          convo.title?.isNotEmpty == true
                              ? convo.title!
                              : convo.conversationId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.body(
                              size: 15,
                              weight: FontWeight.w700,
                              color: AppColors.ink),
                        ),
                        Text(
                          agentOn
                              ? 'AI agent is replying'
                              : 'You are replying directly',
                          style: AppFonts.body(
                              size: 11.5,
                              color:
                                  agentOn ? AppColors.ink3 : AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  if (vm.togglingMode)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('AI',
                            style: AppFonts.body(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: AppColors.ink3)),
                        Switch(
                          value: agentOn,
                          activeTrackColor: AppColors.accent,
                          onChanged: (v) => _toggleAgentChatMode(vm, v),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (vm.error != null)
              Container(
                width: double.infinity,
                color: AppColors.danger.withOpacity(0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(vm.error!,
                    style: AppFonts.body(size: 11.5, color: AppColors.danger)),
              ),
            Expanded(
              child: vm.loading && vm.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : vm.messages.isEmpty
                      ? Center(
                          child: Text('No messages yet.',
                              style: AppFonts.body(
                                  size: 13, color: AppColors.ink3)),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          itemCount: vm.messages.length,
                          itemBuilder: (context, i) => _bubble(vm.messages[i]),
                        ),
            ),
            if (!agentOn)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.line))),
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
                          hintText: 'Reply to the customer…',
                          hintStyle:
                              AppFonts.body(size: 14.5, color: AppColors.ink3),
                          filled: true,
                          fillColor: AppColors.paper2,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 11),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none),
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
                        decoration: BoxDecoration(
                            color:
                                vm.sending ? AppColors.ink3 : AppColors.accent,
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border(top: BorderSide(color: AppColors.line))),
                child: Text(
                  'Turn the AI off above to reply directly in this conversation.',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(size: 12, color: AppColors.ink3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // The SSO server historically stringified a missing last name as the literal word
  // "null" into the display name (e.g. "Hitesh null"), and that bad string is already
  // saved on old messages — strip it here too, not just at the login source.
  String _cleanSenderName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Customer';
    final cleaned =
        raw.replaceAll(RegExp(r'\s+null\b', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }

  // Agent replies are the business's own AI, so they sit on the same side as
  // the business's direct messages — only the customer is on the other side.
  Widget _bubble(GosureMessage m) {
    final kind = m.senderKind;
    final isMine = kind == GosureMessageSender.business ||
        kind == GosureMessageSender.agent;
    final label = switch (kind) {
      GosureMessageSender.customer => _cleanSenderName(m.senderName),
      GosureMessageSender.agent => 'AI agent',
      GosureMessageSender.business => 'You',
    };
    final bubbleColor = switch (kind) {
      GosureMessageSender.customer => AppColors.card,
      GosureMessageSender.agent => AppColors.accentSoft,
      GosureMessageSender.business => AppColors.accent,
    };
    final textColor =
        kind == GosureMessageSender.business ? Colors.white : AppColors.ink;
    final labelColor =
        kind == GosureMessageSender.business ? Colors.white70 : AppColors.ink3;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: kind == GosureMessageSender.customer
              ? Border.all(color: AppColors.line)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppFonts.body(
                    size: 10.5, weight: FontWeight.w700, color: labelColor)),
            const SizedBox(height: 2),
            _markdownText(m.text, textColor),
          ],
        ),
      ),
    );
  }

  Widget _markdownText(String text, Color color) {
    return MarkdownBody(
      data: text,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: AppFonts.body(size: 14, color: color),
        strong: AppFonts.body(size: 14, weight: FontWeight.w700, color: color),
        em: AppFonts.body(size: 14, color: color)
            .copyWith(fontStyle: FontStyle.italic),
        listBullet: AppFonts.body(size: 14, color: color),
        code: AppFonts.mono(size: 12.5, color: color),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        h1: AppFonts.body(size: 18, weight: FontWeight.w700, color: color),
        h2: AppFonts.body(size: 16.5, weight: FontWeight.w700, color: color),
        h3: AppFonts.body(size: 15, weight: FontWeight.w700, color: color),
        blockquoteDecoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
        ),
        tableBorder: TableBorder.all(color: AppColors.line, width: 1),
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}
