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

String timeAgoShort(DateTime? t) {
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

String conversationDisplayTitle(GosureConversation convo) {
  if (convo.title?.trim().isNotEmpty == true) return convo.title!.trim();
  if (convo.customerName?.trim().isNotEmpty == true) return convo.customerName!.trim();
  return convo.conversationId;
}

// Shared by the per-user history screen (see _UserPastChatsView) and, previously,
// the flat conversation list — one row per conversation, opening its detail view.
Widget conversationTile(
  BuildContext context,
  GosureConversation convo,
  String businessId,
  int unreadCount,
  VoidCallback onTap,
) {
  final title = conversationDisplayTitle(convo);
  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
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
              Text(timeAgoShort(convo.updatedAt ?? convo.createdAt),
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
                        size: 11, weight: FontWeight.w700, color: Colors.white),
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

class _BusinessConversationsBody extends StatefulWidget {
  const _BusinessConversationsBody();

  @override
  State<_BusinessConversationsBody> createState() =>
      _BusinessConversationsBodyState();
}

class _BusinessConversationsBodyState
    extends State<_BusinessConversationsBody> {
  final _filterCtrl = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  // Awaiting the push (rather than firing and forgetting) lets us resync the moment the
  // business comes back — otherwise the badge that conversation just cleared would sit
  // stale on screen for up to the 8s poll interval instead of updating immediately.
  Future<void> _openConversation(
      BuildContext context,
      BusinessConversationsViewModel vm,
      GosureConversation convo,
      String businessId) async {
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
    vm.refresh();
  }

  GosureConversation _latestOf(List<GosureConversation> conversations) {
    return conversations.reduce((a, b) {
      final at = a.updatedAt ?? a.createdAt ?? DateTime(0);
      final bt = b.updatedAt ?? b.createdAt ?? DateTime(0);
      return bt.isAfter(at) ? b : a;
    });
  }

  void _openUserHistory(BuildContext context, BusinessConversationsViewModel vm,
      String user, List<GosureConversation> conversations, String businessId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _UserPastChatsView(
          user: user,
          conversations: conversations,
          businessId: businessId,
          vm: vm,
        ),
      ),
    );
  }

  List<MapEntry<String, List<GosureConversation>>> _groupByUser(
      BusinessConversationsViewModel vm,
      List<GosureConversation> conversations) {
    final grouped = <String, List<GosureConversation>>{};
    for (final c in conversations) {
      final user =
          (c.user?.trim().isNotEmpty ?? false) ? c.user!.trim() : 'Unknown';
      grouped.putIfAbsent(user, () => []).add(c);
    }
    DateTime latestOf(List<GosureConversation> list) => list
        .map((c) => c.updatedAt ?? c.createdAt ?? DateTime(0))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final entries = grouped.entries.toList()
      ..sort((a, b) => latestOf(b.value).compareTo(latestOf(a.value)));
    final query = _filterQuery.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((e) {
      if (e.key.toLowerCase().contains(query)) return true;
      final displayName = vm.displayNameFor(e.key);
      return displayName != null && displayName.toLowerCase().contains(query);
    }).toList();
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
            : _usersList(context, vm),
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

  Widget _usersList(BuildContext context, BusinessConversationsViewModel vm) {
    final businessId = vm.businessId!;
    if (vm.loading && vm.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final users = _groupByUser(vm, vm.conversations);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: vm.refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: TextField(
              controller: _filterCtrl,
              onChanged: (v) => setState(() => _filterQuery = v),
              style: AppFonts.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Search by username',
                hintStyle: AppFonts.body(size: 13.5, color: AppColors.ink3),
                prefixIcon: Icon(Icons.search, size: 19, color: AppColors.ink3),
                filled: true,
                fillColor: AppColors.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent)),
              ),
            ),
          ),
          Expanded(
            child: vm.conversations.isEmpty
                ? Center(
                    child: Text('No conversations available.',
                        style:
                            AppFonts.body(size: 13.5, color: AppColors.ink3)),
                  )
                : users.isEmpty
                    ? Center(
                        child: Text('No users match "$_filterQuery".',
                            style: AppFonts.body(
                                size: 13.5, color: AppColors.ink3)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                        itemCount: users.length + (vm.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i >= users.length) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) => vm.loadMore());
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          final entry = users[i];
                          return _userTile(
                              context, vm, entry.key, entry.value, businessId);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(BuildContext context, BusinessConversationsViewModel vm,
      String user, List<GosureConversation> conversations, String businessId) {
    vm.ensureDisplayName(user, conversations.first);
    final displayName = vm.displayNameFor(user) ?? user;
    final unread =
        conversations.fold<int>(0, (sum, c) => sum + vm.unreadCountFor(c));
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          _openConversation(context, vm, _latestOf(conversations), businessId),
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
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: AppFonts.body(
                    size: 15, weight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                      '${conversations.length} chat${conversations.length == 1 ? '' : 's'}',
                      style: AppFonts.body(size: 11.5, color: AppColors.ink3)),
                ],
              ),
            ),
            if (unread > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(11)),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: AppFonts.body(
                      size: 11, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
            ],
            IconButton(
              icon: Icon(Icons.history, color: AppColors.accent),
              tooltip: 'Past chats',
              onPressed: () => _openUserHistory(
                  context, vm, user, conversations, businessId),
            ),
          ],
        ),
      ),
    );
  }
}

// Pushed when tapping a user card's timer icon — that user's own conversations,
// newest first, each opening the same conversation detail view as before.
class _UserPastChatsView extends StatelessWidget {
  final String user;
  final List<GosureConversation> conversations;
  final String businessId;
  final BusinessConversationsViewModel vm;

  const _UserPastChatsView({
    required this.user,
    required this.conversations,
    required this.businessId,
    required this.vm,
  });

  Future<void> _openConversation(
      BuildContext context, GosureConversation convo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ConversationDetailView(
              conversation: convo, businessId: businessId)),
    );
    vm.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...conversations]..sort((a, b) {
        final at = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bt = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bt.compareTo(at);
      });

    return Scaffold(
      backgroundColor: AppColors.paper2,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(vm.displayNameFor(user) ?? user,
            style: AppFonts.display(size: 17)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final convo = sorted[i];
            return conversationTile(
                context,
                convo,
                businessId,
                vm.unreadCountFor(convo),
                () => _openConversation(context, convo));
          },
        ),
      ),
    );
  }
}
