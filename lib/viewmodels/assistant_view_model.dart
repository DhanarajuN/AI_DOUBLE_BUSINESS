import 'package:flutter/foundation.dart';
import '../models/business_profile.dart';
import '../models/industry.dart';
import '../repositories/workspace_repository.dart';
import '../services/llm_service.dart';

class AssistantViewModel extends ChangeNotifier {
  final WorkspaceRepository _workspace;

  AssistantViewModel(this._workspace) {
    _workspace.addListener(notifyListeners);
  }

  bool _sending = false;
  bool get sending => _sending;

  String get brand => _workspace.brand;
  List<Map<String, String>> get chatMessages => _workspace.chatMessages;
  BusinessProfile? get business => _workspace.business;
  bool get keyReady => _workspace.keyReady;

  List<String> get suggestions =>
      industryById(business?.industryId).services.map((s) => 'I need help with: $s').toList();

  Future<void> clearChat() => _workspace.clearChat();

  String _systemPrompt() {
    final ind = industryById(business?.industryId);
    var ctx = '';
    final docs = _workspace.docs;
    if (docs.isNotEmpty) {
      final parts = <String>[];
      var budget = 9000;
      for (final d in docs) {
        final chunk = '# ${d.name}\n${d.text}';
        final slice = chunk.length > budget ? chunk.substring(0, budget) : chunk;
        if (slice.isEmpty) break;
        parts.add(slice);
        budget -= slice.length;
        if (budget <= 0) break;
      }
      ctx =
          "\n\nYou have access to the business's own documents. Answer FROM these when relevant, and name the document you drew from. If the answer isn't in them, say so plainly rather than inventing figures.\n\n<documents>\n${parts.join('\n\n---\n\n')}\n</documents>";
    } else {
      ctx = '\n\nNo documents have been uploaded yet. Answer helpfully in general terms and suggest adding relevant documents under Docs for precise answers.';
    }
    final businessName = business?.name ?? 'the business';
    return 'You are the customer-facing AI assistant for "$businessName", a ${ind.name.toLowerCase()} business in India. '
        'You speak to their customers on their behalf, answering questions and helping with things like ${ind.services.join(', ').toLowerCase()}. '
        'Be helpful, professional and on-brand. When a customer wants to proceed (book, renew, apply, claim), confirm the key details and state clearly what happens next. '
        'Style: warm, direct and specific. Lead with the answer. Quote concrete figures and dates when you have them. Keep replies short. Never fabricate numbers or dates.'
        '$ctx';
  }

  Future<void> send(String rawText) async {
    final content = rawText.trim();
    if (content.isEmpty || _sending) return;
    _sending = true;
    notifyListeners();
    await _workspace.addChatMessage('user', content);

    try {
      final all = _workspace.chatMessages;
      final history = all.length > 12 ? all.sublist(all.length - 12) : all;
      final messages = history.map((m) => {'role': m['role']!, 'content': m['content']!}).toList();
      final result = await LlmService.call(
        provider: _workspace.provider,
        apiKey: _workspace.apiKey,
        model: _workspace.model.trim().isNotEmpty ? _workspace.model.trim() : kProviders[_workspace.provider]!.model,
        system: _systemPrompt(),
        messages: messages,
      );
      final reply = result.text.trim().isEmpty ? "I didn't catch that — could you rephrase?" : result.text.trim();
      await _workspace.addChatMessage('assistant', reply);
      await _workspace.recordUsage(result.inputTokens, result.outputTokens);
    } catch (e) {
      await _workspace.addChatMessage('assistant', "Couldn't reach the model. ${LlmService.friendlyError(e)}");
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _workspace.removeListener(notifyListeners);
    super.dispose();
  }
}
