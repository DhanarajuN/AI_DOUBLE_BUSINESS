import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gosure_conversation.dart';
import '../repositories/business_conversations_repository.dart';
import '../services/api_client.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../viewmodels/business_conversations_view_model.dart';
import 'conversation_detail_view.dart';

class BusinessConversationsView extends StatelessWidget {
  const BusinessConversationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => BusinessConversationsViewModel(
        ctx.read<BusinessConversationsRepository>(),
        ctx.read<SessionStorage>(),
        ctx.read<ApiClient>(),
      )..init(),
      child: const _BusinessConversationsBody(),
    );
  }
}

class _BusinessConversationsBody extends StatefulWidget {
  const _BusinessConversationsBody();

  @override
  State<_BusinessConversationsBody> createState() =>
      _BusinessConversationsBodyState();
}

class _BusinessConversationsBodyState
    extends State<_BusinessConversationsBody> {
  String _timeAgo(DateTime? t) {
    if (t == null) return '';
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 60) return 'just now';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ago';
    final d = h ~/ 24;
    return '${d}d ago';
  }

  // Awaiting the push (rather than firing and forgetting) lets us resync the moment the
  // business comes back — otherwise the badge that conversation just cleared would sit
  // stale on screen for up to the 8s poll interval instead of updating immediately.
  Future<void> _openConversation(
      BuildContext context, GosureConversation convo, String businessId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ConversationDetailView(
              conversation: convo, businessId: businessId)),
    );
    if (!context.mounted) return;
    // The push's Future completes the instant pop() is called, while the pop's transition
    // animation is still settling — refreshing (and rebuilding this list) right then races
    // Flutter's own frame processing and throws "!_dirty is not true". Yielding a frame first
    // lets the transition finish before this widget tree gets touched again.
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;
    context.read<BusinessConversationsViewModel>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BusinessConversationsViewModel>();

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Conversations', style: AppFonts.display(size: 17)),
      ),
      body: SafeArea(
        child: vm.needsBusinessId
            ? _businessUnresolved(vm)
            : _conversationsList(context, vm),
      ),
    );
  }

  Widget _businessUnresolved(BusinessConversationsViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 40, color: AppColors.accent),
            const SizedBox(height: 14),
            Text("Couldn't find your business",
                style: AppFonts.display(size: 18)),
            const SizedBox(height: 8),
            Text(
              "We couldn't match this account to a business yet. Try again once it's set up.",
              textAlign: TextAlign.center,
              style: AppFonts.body(size: 13, color: AppColors.ink3),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: vm.retryResolve,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationsList(
      BuildContext context, BusinessConversationsViewModel vm) {
    final businessId = vm.businessId!;
    if (vm.loading && vm.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && vm.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 32),
              const SizedBox(height: 10),
              Text(vm.error!,
                  textAlign: TextAlign.center,
                  style: AppFonts.body(size: 13, color: AppColors.ink3)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: vm.refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (vm.conversations.isEmpty) {
      return Center(
        child: Text('No conversations yet.',
            style: AppFonts.body(size: 13.5, color: AppColors.ink3)),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: vm.conversations.length + (vm.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= vm.conversations.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => vm.loadMore());
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final convo = vm.conversations[i];
          return _conversationTile(
              context, convo, businessId, vm.unreadCountFor(convo));
        },
      ),
    );
  }

  Widget _conversationTile(BuildContext context, GosureConversation convo,
      String businessId, int unreadCount) {
    final title =
        convo.title?.isNotEmpty == true ? convo.title! : convo.conversationId;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openConversation(context, convo, businessId),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.accentSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?',
                style: AppFonts.body(
                    size: 15, weight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    convo.agentChatMode ? 'AI replying' : 'You are replying',
                    style: AppFonts.body(
                        size: 11.5,
                        color: convo.agentChatMode
                            ? AppColors.ink3
                            : AppColors.accent),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_timeAgo(convo.updatedAt ?? convo.createdAt),
                    style: AppFonts.body(size: 11, color: AppColors.ink3)),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(11)),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: AppFonts.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
