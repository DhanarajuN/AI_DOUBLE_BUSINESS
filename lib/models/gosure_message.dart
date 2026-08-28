enum GosureMessageSender { customer, agent, business, broker }

class GosureMessage {
  final String messageId;
  final String? conversationId;
  final String? parentMessageId;
  final String text;
  final String? sender;
  // WhatsApp-style display name for this message's sender — the customer's
  // own name, or the business's name for a live-handoff message (resolved
  // server-side, see librechat-backend's Gosure/businessLookup.js).
  final String? senderName;
  final bool isCreatedByUser;
  final String? user;
  final String? businessId;
  final DateTime? createdAt;

  const GosureMessage({
    required this.messageId,
    this.conversationId,
    this.parentMessageId,
    required this.text,
    this.sender,
    this.senderName,
    required this.isCreatedByUser,
    this.user,
    this.businessId,
    this.createdAt,
  });

  // businessId is tagged on every message in the conversation (customer's,
  // agent's, and the business's own alike) — it says which business the
  // conversation is about, not who sent this particular message, so it can't
  // be the signal here. The direct-message route (POST
  // /:conversationId/messages in conversations.js) is the one and only place
  // that ever sets `sender: 'Business'` or `sender: 'Broker'` literally —
  // customer messages and agent replies never do, regardless of businessId.
  GosureMessageSender get senderKind {
    if (sender == 'Business') return GosureMessageSender.business;
    if (sender == 'Broker') return GosureMessageSender.broker;
    return isCreatedByUser
        ? GosureMessageSender.customer
        : GosureMessageSender.agent;
  }

  factory GosureMessage.fromJson(Map<String, dynamic> json) {
    // The gosure contract's message shape has a flat `text`. Agent replies are stored
    // with `text` as an EMPTY STRING (not null/absent) and their real body nested under
    // a `content` list instead — so a plain `?? ` fallback never kicks in (`""` isn't
    // null) and silently renders blank. Treat blank-or-absent `text` as "use content".
    final rawText = json['text'] as String?;
    final content = json['content'] as List?;
    final extractedText = (content != null && content.isNotEmpty)
        ? content
            .whereType<Map>()
            .where((c) => c['type'] == 'text')
            .map((c) => c['text']?.toString() ?? '')
            .join('\n\n')
        : null;
    return GosureMessage(
      messageId: json['messageId'] as String? ?? json['_id'] as String? ?? '',
      conversationId: json['conversationId'] as String?,
      parentMessageId: json['parentMessageId'] as String?,
      text: (rawText != null && rawText.isNotEmpty)
          ? rawText
          : (extractedText ?? ''),
      sender: json['sender'] as String?,
      senderName: json['senderName'] as String?,
      isCreatedByUser: json['isCreatedByUser'] as bool? ?? false,
      user: json['user'] as String?,
      businessId: json['businessId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
